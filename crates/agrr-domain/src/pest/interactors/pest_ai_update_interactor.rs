//! Ruby: `Domain::Pest::Interactors::PestAiUpdateInteractor`

use crate::pest::dtos::{HttpJsonEnvelope, HttpStatus};
use crate::pest::entities::PestEntity;
use crate::pest::gateways::PestGateway;
use crate::pest::interactors::pest_ai_create_interactor::PestAiQueryGateway;
use crate::pest::mappers::interpret_pest_ai_response;
use crate::pest::ports::PestAiUpdateInteractorPort;
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pest_policy;
use crate::shared::ports::logger_port::LoggerPort;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;
use serde_json::Value;

pub struct PestAiUpdateInteractor<'a, U, PG, AQ, UI, L, T> {
    user_id: i64,
    user_lookup: &'a U,
    pest_gateway: &'a PG,
    pest_ai_query_gateway: &'a AQ,
    update_interactor: &'a UI,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, U, PG, AQ, UI, L, T> PestAiUpdateInteractor<'a, U, PG, AQ, UI, L, T>
where
    U: UserLookupGateway,
    PG: PestGateway,
    AQ: PestAiQueryGateway,
    UI: PestAiUpdateInteractorPort,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        user_id: i64,
        user_lookup: &'a U,
        pest_gateway: &'a PG,
        pest_ai_query_gateway: &'a AQ,
        update_interactor: &'a UI,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            user_id,
            user_lookup,
            pest_gateway,
            pest_ai_query_gateway,
            update_interactor,
            logger,
            translator,
        }
    }

    pub fn call(
        &self,
        pest_id: i64,
        pest_query_name: &str,
    ) -> Result<HttpJsonEnvelope, Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let opts = TranslateOptions::default();

        let pn = pest_query_name.trim();
        if pn.is_empty() {
            let message = self
                .translator
                .t("api.errors.pests.name_required", &opts);
            return Ok(HttpJsonEnvelope::new(
                HttpStatus::BadRequest,
                serde_json::json!({ "error": message }),
            ));
        }

        let pest_entity = match self.load_authorized_pest_entity(&user, pest_id) {
            Some(entity) => entity,
            None => {
                let message = self.translator.t("api.errors.pests.not_found", &opts);
                return Ok(HttpJsonEnvelope::new(
                    HttpStatus::NotFound,
                    serde_json::json!({ "error": message }),
                ));
            }
        };

        self.logger.info(&format!(
            "🤖 [AI Pest] Querying pest info for update: {pn} (ID: {})",
            pest_entity.id
        ));

        let pest_info = self.pest_ai_query_gateway.fetch_pest_json(pn, &[])?;
        let interpreted = interpret_pest_ai_response(&pest_info, self.translator, false);
        if let Some(failure) = interpreted.failure {
            return Ok(HttpJsonEnvelope::new(
                failure.http_status,
                serde_json::json!({ "error": failure.message }),
            ));
        }

        let pest_data = interpreted.pest_data.unwrap_or(Value::Null);

        self.logger.info(&format!(
            "🔄 [AI Pest] Updating pest#{} with latest data from agrr",
            pest_entity.id
        ));

        let attrs = attrs_from_pest_data(&pest_data);
        let result = self.update_interactor.call(pest_entity.id, attrs);

        if !result.success {
            let error = result.error.unwrap_or_else(|| "unknown error".into());
            self.logger
                .error(&format!("❌ [AI Pest] Failed to update: {error}"));
            return Ok(HttpJsonEnvelope::new(
                HttpStatus::UnprocessableEntity,
                serde_json::json!({ "error": error }),
            ));
        }

        let pest_entity = result.data.expect("success implies data");
        self.logger.info(&format!(
            "✅ [AI Pest] Updated pest#{}: {}",
            pest_entity.id, pest_entity.name
        ));

        let mut msg_opts = TranslateOptions::new();
        msg_opts.insert("name".into(), pest_entity.name.clone());
        let message = self
            .translator
            .t("api.messages.pests.updated_by_ai", &msg_opts);

        Ok(HttpJsonEnvelope::new(
            HttpStatus::Ok,
            serde_json::json!({
                "success": true,
                "pest_id": pest_entity.id,
                "pest_name": pest_entity.name,
                "name_scientific": pest_entity.name_scientific,
                "family": pest_entity.family,
                "order": pest_entity.order,
                "description": pest_entity.description,
                "occurrence_season": pest_entity.occurrence_season,
                "is_reference": pest_entity.is_reference,
                "message": message,
            }),
        ))
    }

    fn load_authorized_pest_entity(&self, user: &crate::shared::user::User, pest_id: i64) -> Option<PestEntity> {
        let access_filter = pest_policy::record_access_filter(*user);
        let entity = self.pest_gateway.find_by_id(pest_id).ok()?;
        reference_record_authorization::assert_edit_allowed(&access_filter, &entity).ok()?;
        Some(entity)
    }
}

fn attrs_from_pest_data(data: &Value) -> AttrMap {
    let mut pairs: Vec<(&str, AttrValue)> = Vec::new();
    for key in [
        "name",
        "name_scientific",
        "family",
        "order",
        "description",
        "occurrence_season",
    ] {
        if let Some(s) = data.get(key).and_then(Value::as_str) {
            pairs.push((key, AttrValue::from(s)));
        }
    }
    if let Some(v) = data.get("temperature_profile") {
        if let Ok(s) = serde_json::to_string(v) {
            pairs.push(("temperature_profile", AttrValue::Str(s)));
        }
    }
    if let Some(v) = data.get("thermal_requirement") {
        if let Ok(s) = serde_json::to_string(v) {
            pairs.push(("thermal_requirement", AttrValue::Str(s)));
        }
    }
    let control_methods = data
        .get("control_methods")
        .cloned()
        .unwrap_or(Value::Array(vec![]));
    if let Ok(s) = serde_json::to_string(&control_methods) {
        pairs.push(("control_methods", AttrValue::Str(s)));
    }
    attr_map_from_pairs(pairs)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::pest::entities::PestEntity;
    use crate::pest::ports::PestAiUpdateResult;
    use crate::shared::user::User;
    use std::sync::Mutex;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            match key {
                "api.errors.pests.name_required" => "害虫名を入力してください".into(),
                "api.errors.pests.not_found" => "害虫が見つかりません".into(),
                _ => key.into(),
            }
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct StubLogger;
    impl LoggerPort for StubLogger {
        fn debug(&self, _: &str) {}
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
    }

    struct StubAiGateway {
        response: Value,
    }

    impl PestAiQueryGateway for StubAiGateway {
        fn fetch_pest_json(
            &self,
            _: &str,
            _: &[Value],
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.response.clone())
        }
    }

    struct StubPestGateway {
        pest: Option<PestEntity>,
        find_error: bool,
    }

    impl PestGateway for StubPestGateway {

        fn list_pests_for_crop_filtered(
            &self,
            _: i64,
            _: &[i64],
            _: crate::pest::gateways::CropPestListOrder,
        ) -> Result<Vec<crate::pest::entities::PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            pest_id: i64,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            if self.find_error {
                return Err(Box::new(RecordNotFoundError));
            }
            assert_eq!(pest_id, 7);
            Ok(self.pest.clone().expect("pest"))
        }
        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn find_pest_show_detail(
            &self,
            _: i64,
        ) -> Result<crate::pest::dtos::PestShowDetail, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<crate::pest::dtos::PestDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<
            crate::pest::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }    }

    struct StubUpdate {
        result: PestAiUpdateResult,
        calls: Mutex<Vec<(i64, AttrMap)>>,
    }

    impl PestAiUpdateInteractorPort for StubUpdate {
        fn call(&self, pest_id: i64, attrs: AttrMap) -> PestAiUpdateResult {
            self.calls.lock().unwrap().push((pest_id, attrs));
            self.result.clone()
        }
    }

    fn build_pest(id: i64, name: &str) -> PestEntity {
        PestEntity {
            id,
            user_id: Some(1),
            name: name.into(),
            name_scientific: Some("Aphididae".into()),
            family: Some("Aphididae".into()),
            order: Some("Hemiptera".into()),
            description: Some("desc".into()),
            occurrence_season: Some("summer".into()),
            region: None,
            is_reference: false,
            created_at: None,
            updated_at: None,
        }
    }

    fn build_interactor<'a>(
        lookup: &'a StubLookup,
        pest_gateway: &'a StubPestGateway,
        ai_gateway: &'a StubAiGateway,
        update: &'a StubUpdate,
    ) -> PestAiUpdateInteractor<'a, StubLookup, StubPestGateway, StubAiGateway, StubUpdate, StubLogger, StubTranslator>
    {
        PestAiUpdateInteractor::new(
            1,
            lookup,
            pest_gateway,
            ai_gateway,
            update,
            &StubLogger,
            &StubTranslator,
        )
    }

    // Ruby: test "returns bad_request when pest query name is blank"
    #[test]
    fn returns_bad_request_when_pest_query_name_is_blank() {
        let pest_gateway = StubPestGateway {
            pest: Some(build_pest(7, "アブラムシ")),
            find_error: false,
        };
        let ai_gateway = StubAiGateway {
            response: serde_json::json!({}),
        };
        let update = StubUpdate {
            result: PestAiUpdateResult {
                success: false,
                data: None,
                error: None,
            },
            calls: Mutex::new(vec![]),
        };
        let lookup = StubLookup(User::new(1, true));
        let interactor = build_interactor(&lookup, &pest_gateway, &ai_gateway, &update);

        let envelope = interactor.call(7, "  ").unwrap();

        assert_eq!(envelope.status, HttpStatus::BadRequest);
        assert_eq!(
            envelope.body.get("error").and_then(Value::as_str),
            Some("害虫名を入力してください")
        );
        assert!(update.calls.lock().unwrap().is_empty());
    }

    // Ruby: test "returns not_found when pest is not accessible"
    #[test]
    fn returns_not_found_when_pest_is_not_accessible() {
        let pest_gateway = StubPestGateway {
            pest: None,
            find_error: true,
        };
        let ai_gateway = StubAiGateway {
            response: serde_json::json!({}),
        };
        let update = StubUpdate {
            result: PestAiUpdateResult {
                success: false,
                data: None,
                error: None,
            },
            calls: Mutex::new(vec![]),
        };
        let lookup = StubLookup(User::new(1, true));
        let interactor = build_interactor(&lookup, &pest_gateway, &ai_gateway, &update);

        let envelope = interactor.call(7, "アブラムシ").unwrap();

        assert_eq!(envelope.status, HttpStatus::NotFound);
        assert_eq!(
            envelope.body.get("error").and_then(Value::as_str),
            Some("害虫が見つかりません")
        );
    }

    // Ruby: test "returns unprocessable_entity when update interactor fails"
    #[test]
    fn returns_unprocessable_entity_when_update_interactor_fails() {
        let pest_gateway = StubPestGateway {
            pest: Some(build_pest(7, "アブラムシ")),
            find_error: false,
        };
        let ai_gateway = StubAiGateway {
            response: serde_json::json!({
                "success": true,
                "data": { "pest": { "name": "アブラムシ" } }
            }),
        };
        let update = StubUpdate {
            result: PestAiUpdateResult {
                success: false,
                data: None,
                error: Some("validation failed".into()),
            },
            calls: Mutex::new(vec![]),
        };
        let lookup = StubLookup(User::new(1, true));
        let interactor = build_interactor(&lookup, &pest_gateway, &ai_gateway, &update);

        let envelope = interactor.call(7, "アブラムシ").unwrap();

        assert_eq!(envelope.status, HttpStatus::UnprocessableEntity);
        assert_eq!(
            envelope.body.get("error").and_then(Value::as_str),
            Some("validation failed")
        );
    }

    // Ruby: test "returns ok envelope when agrr data updates pest successfully"
    #[test]
    fn returns_ok_envelope_when_agrr_data_updates_pest_successfully() {
        let pest_gateway = StubPestGateway {
            pest: Some(build_pest(7, "アブラムシ")),
            find_error: false,
        };
        let ai_gateway = StubAiGateway {
            response: serde_json::json!({
                "success": true,
                "data": {
                    "pest": {
                        "name": "アブラムシ（更新）",
                        "name_scientific": "Aphididae",
                        "family": "Aphididae",
                        "order": "Hemiptera",
                        "description": "desc",
                        "occurrence_season": "summer"
                    }
                }
            }),
        };
        let updated = build_pest(7, "アブラムシ（更新）");
        let update = StubUpdate {
            result: PestAiUpdateResult {
                success: true,
                data: Some(updated),
                error: None,
            },
            calls: Mutex::new(vec![]),
        };
        let lookup = StubLookup(User::new(1, true));
        let interactor = build_interactor(&lookup, &pest_gateway, &ai_gateway, &update);

        let envelope = interactor.call(7, "アブラムシ").unwrap();

        assert_eq!(envelope.status, HttpStatus::Ok);
        assert_eq!(envelope.body.get("success"), Some(&Value::Bool(true)));
        assert_eq!(envelope.body.get("pest_id"), Some(&serde_json::json!(7)));
        assert_eq!(
            envelope.body.get("pest_name").and_then(Value::as_str),
            Some("アブラムシ（更新）")
        );
    }
}
