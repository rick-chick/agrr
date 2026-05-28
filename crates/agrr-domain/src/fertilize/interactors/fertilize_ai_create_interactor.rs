//! Ruby: `Domain::Fertilize::Interactors::FertilizeAiCreateInteractor`

use std::collections::BTreeMap;

use crate::fertilize::dtos::{
    FertilizeAiCreateFailure, FertilizeAiCreateOutput, HttpStatus,
};
use crate::fertilize::gateways::{FertilizeAiQueryGateway, FertilizeGateway};
use crate::fertilize::mappers::normalize_fertilize_payload;
use crate::fertilize::ports::{
    AiCreateInteractorPort, AiUpdateInteractorPort, FertilizeAiCreateOutputPort,
};
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::fertilize_policy;
use crate::shared::ports::logger_port::LoggerPort;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

pub struct FertilizeAiCreateInteractor<'a, O, U, FG, AQ, CI, UI, L, T> {
    output_port: &'a mut O,
    user_id: i64,
    user_lookup: &'a U,
    fertilize_gateway: &'a FG,
    fertilize_ai_query_gateway: &'a AQ,
    create_interactor: &'a CI,
    update_interactor: &'a UI,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, O, U, FG, AQ, CI, UI, L, T> FertilizeAiCreateInteractor<'a, O, U, FG, AQ, CI, UI, L, T>
where
    O: FertilizeAiCreateOutputPort,
    U: UserLookupGateway,
    FG: FertilizeGateway,
    AQ: FertilizeAiQueryGateway,
    CI: AiCreateInteractorPort,
    UI: AiUpdateInteractorPort,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        user_lookup: &'a U,
        fertilize_gateway: &'a FG,
        fertilize_ai_query_gateway: &'a AQ,
        create_interactor: &'a CI,
        update_interactor: &'a UI,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            output_port,
            user_id,
            user_lookup,
            fertilize_gateway,
            fertilize_ai_query_gateway,
            create_interactor,
            update_interactor,
            logger,
            translator,
        }
    }

    pub fn call(
        &mut self,
        fertilize_query_name: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let opts = TranslateOptions::default();

        if user.anonymous {
            let message = self.translator.t("auth.api.login_required", &opts);
            self.output_port.on_failure(FertilizeAiCreateFailure::new(
                HttpStatus::Unauthorized,
                message,
            ));
            return Ok(());
        }

        let fertilize_name = fertilize_query_name.trim();
        if fertilize_name.is_empty() {
            let message = self
                .translator
                .t("api.errors.fertilizes.name_required", &opts);
            self.output_port.on_failure(FertilizeAiCreateFailure::new(
                HttpStatus::BadRequest,
                message,
            ));
            return Ok(());
        }

        self.logger
            .info(&format!("🤖 [AI Fertilize] Querying fertilize info for: {fertilize_name}"));
        let fertilize_info = self
            .fertilize_ai_query_gateway
            .fetch_for_create(fertilize_name)?;

        if fertilize_info.get("success") == Some(&serde_json::Value::Bool(false)) {
            let error_msg = fertilize_info
                .get("error")
                .and_then(|v| v.as_str())
                .map(str::to_string)
                .unwrap_or_else(|| {
                    self.translator
                        .t("api.errors.fertilizes.fetch_failed", &opts)
                });
            let status = if fertilize_info.get("code") == Some(&serde_json::Value::String(
                "daemon_not_running".into(),
            )) {
                HttpStatus::ServiceUnavailable
            } else {
                HttpStatus::UnprocessableEntity
            };
            self.output_port
                .on_failure(FertilizeAiCreateFailure::new(status, error_msg));
            return Ok(());
        }

        let fertilize_data = match normalize_fertilize_payload(&fertilize_info) {
            Some(data) => data,
            None => {
                let message = self
                    .translator
                    .t("api.errors.fertilizes.invalid_payload", &opts);
                self.output_port.on_failure(FertilizeAiCreateFailure::new(
                    HttpStatus::UnprocessableEntity,
                    message,
                ));
                return Ok(());
            }
        };

        let fertilize_name_from_agrr = fertilize_data
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or(fertilize_name)
            .to_string();
        let base_attrs = base_attrs_from_payload(&fertilize_data);

        self.logger.info(&format!(
            "📊 [AI Fertilize] Retrieved data: name={}, n={:?}, p={:?}, k={:?}, package_size={:?}",
            fertilize_name_from_agrr,
            json_f64(fertilize_data.get("n")),
            json_f64(fertilize_data.get("p")),
            json_f64(fertilize_data.get("k")),
            json_f64(fertilize_data.get("package_size")),
        ));

        let existing_fertilize = self
            .fertilize_gateway
            .find_by_name(self.user_id, &fertilize_name_from_agrr)?;

        let (success, data, error, http_status) = if let Some(existing) = existing_fertilize {
            self.logger.info(&format!(
                "🔄 [AI Fertilize] Updating existing fertilize#{}: {}",
                existing.id.unwrap_or(0),
                fertilize_name_from_agrr
            ));
            let result = self.update_interactor.call(
                existing.id.unwrap_or(0),
                base_attrs.clone(),
            );
            (
                result.success,
                result.data,
                result.error,
                HttpStatus::Ok,
            )
        } else {
            self.logger.info(&format!(
                "🆕 [AI Fertilize] Creating new fertilize: {fertilize_name_from_agrr}"
            ));
            let normalized = fertilize_policy::normalize_attrs_for_create(&user, base_attrs.clone());
            let mut attrs_for_create = base_attrs;
            if let Some(AttrValue::Int(uid)) = normalized.get("user_id") {
                attrs_for_create.insert("user_id".into(), AttrValue::Int(*uid));
            }
            if let Some(v) = normalized.get("is_reference") {
                attrs_for_create.insert("is_reference".into(), v.clone());
            }
            let result = self.create_interactor.call(attrs_for_create);
            (
                result.success,
                result.data,
                result.error,
                HttpStatus::Created,
            )
        };

        if !success {
            let error = error.unwrap_or_else(|| "unknown error".into());
            self.logger
                .error(&format!("❌ [AI Fertilize] Failed: {error}"));
            self.output_port.on_failure(FertilizeAiCreateFailure::new(
                HttpStatus::UnprocessableEntity,
                error,
            ));
            return Ok(());
        }

        let fertilize_entity = data.expect("success implies data");
        self.logger.info(&format!(
            "✅ [AI Fertilize] Saved fertilize#{}: {}",
            fertilize_entity.id.unwrap_or(0),
            fertilize_entity.name
        ));

        let mut msg_opts = TranslateOptions::new();
        msg_opts.insert("name".into(), fertilize_entity.name.clone());
        let message = self
            .translator
            .t("api.messages.fertilizes.created_by_ai", &msg_opts);

        self.output_port.on_success(FertilizeAiCreateOutput::new(
            http_status,
            fertilize_entity.id.unwrap_or(0),
            fertilize_entity.name.clone(),
            fertilize_entity.n,
            fertilize_entity.p,
            fertilize_entity.k,
            fertilize_entity.description.clone(),
            fertilize_entity.package_size,
            message,
        ));
        Ok(())
    }
}

fn json_f64(value: Option<&serde_json::Value>) -> Option<f64> {
    value.and_then(|v| v.as_f64())
}

fn base_attrs_from_payload(data: &BTreeMap<String, serde_json::Value>) -> AttrMap {
    let mut pairs = Vec::new();
    if let Some(name) = data.get("name").and_then(|v| v.as_str()) {
        pairs.push(("name", AttrValue::from(name)));
    }
    for key in ["n", "p", "k", "package_size"] {
        if let Some(v) = data.get(key).and_then(|v| v.as_f64()) {
            pairs.push((key, AttrValue::Str(v.to_string())));
        }
    }
    if let Some(desc) = data.get("description").and_then(|v| v.as_str()) {
        pairs.push(("description", AttrValue::from(desc)));
    }
    attr_map_from_pairs(pairs)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::fertilize::entities::{FertilizeEntity, FertilizeEntityAttrs};
    use crate::fertilize::ports::{AiCreateResult, AiUpdateResult};
    use crate::shared::user::User;

    struct AnonymousLookup;
    impl UserLookupGateway for AnonymousLookup {
        fn find(&self, _: i64) -> User {
            User {
                id: 1,
                admin: false,
                anonymous: true,
            }
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, _: &str, _: &TranslateOptions) -> String {
            "login required".into()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct NoopLogger;
    impl LoggerPort for NoopLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    struct NoopGateways;
    impl FertilizeGateway for NoopGateways {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<
            crate::fertilize::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(None)
        }
    }

    impl FertilizeAiQueryGateway for NoopGateways {
        fn fetch_for_create(
            &self,
            _: &str,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn fetch_for_update(
            &self,
            _: i64,
            _: &str,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct NoopAiPorts;
    impl AiCreateInteractorPort for NoopAiPorts {
        fn call(&self, _: AttrMap) -> AiCreateResult {
            AiCreateResult {
                success: false,
                data: None,
                error: Some("noop".into()),
            }
        }
    }
    impl AiUpdateInteractorPort for NoopAiPorts {
        fn call(&self, _: i64, _: AttrMap) -> AiUpdateResult {
            AiUpdateResult {
                success: false,
                data: None,
                error: Some("noop".into()),
            }
        }
    }

    struct SpyOutput {
        failure: Option<FertilizeAiCreateFailure>,
    }

    impl FertilizeAiCreateOutputPort for SpyOutput {
        fn on_success(&mut self, _: FertilizeAiCreateOutput) {}
        fn on_failure(&mut self, dto: FertilizeAiCreateFailure) {
            self.failure = Some(dto);
        }
    }

    // Ruby: test "calls on_failure when user is anonymous"
    #[test]
    fn calls_on_failure_when_user_is_anonymous() {
        let mut output = SpyOutput { failure: None };
        let mut interactor = FertilizeAiCreateInteractor::new(
            &mut output,
            1,
            &AnonymousLookup,
            &NoopGateways,
            &NoopGateways,
            &NoopAiPorts,
            &NoopAiPorts,
            &NoopLogger,
            &StubTranslator,
        );
        interactor.call("尿素").expect("handled");
        let failure = output.failure.expect("failure");
        assert_eq!(failure.http_status, HttpStatus::Unauthorized);
    }
}
