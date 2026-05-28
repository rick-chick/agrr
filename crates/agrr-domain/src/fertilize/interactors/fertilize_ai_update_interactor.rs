//! Ruby: `Domain::Fertilize::Interactors::FertilizeAiUpdateInteractor`

use crate::fertilize::dtos::{HttpJsonEnvelope, HttpStatus};
use crate::fertilize::gateways::{FertilizeAiQueryGateway, FertilizeGateway};
use crate::fertilize::mappers::normalize_fertilize_payload;
use crate::fertilize::ports::AiUpdateInteractorPort;
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::fertilize_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::logger_port::LoggerPort;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct FertilizeAiUpdateInteractor<'a, U, FG, AQ, UI, L, T> {
    user_id: i64,
    user_lookup: &'a U,
    fertilize_gateway: &'a FG,
    fertilize_ai_query_gateway: &'a AQ,
    update_interactor: &'a UI,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, U, FG, AQ, UI, L, T> FertilizeAiUpdateInteractor<'a, U, FG, AQ, UI, L, T>
where
    U: UserLookupGateway,
    FG: FertilizeGateway,
    AQ: FertilizeAiQueryGateway,
    UI: AiUpdateInteractorPort,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        user_id: i64,
        user_lookup: &'a U,
        fertilize_gateway: &'a FG,
        fertilize_ai_query_gateway: &'a AQ,
        update_interactor: &'a UI,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            user_id,
            user_lookup,
            fertilize_gateway,
            fertilize_ai_query_gateway,
            update_interactor,
            logger,
            translator,
        }
    }

    pub fn call(
        &self,
        fertilize_id: i64,
        fertilize_query_name: &str,
    ) -> Result<HttpJsonEnvelope, Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let opts = TranslateOptions::default();

        let fertilize_name = fertilize_query_name.trim();
        if fertilize_name.is_empty() {
            let message = self
                .translator
                .t("api.errors.fertilizes.name_required", &opts);
            return Ok(HttpJsonEnvelope::new(
                HttpStatus::BadRequest,
                serde_json::json!({ "error": message }),
            ));
        }

        let fertilize_record = match self.load_authorized_fertilize(&user, fertilize_id) {
            Some(entity) => entity,
            None => {
                let message = self.translator.t(
                    "api.errors.fertilizes.not_found",
                    &opts,
                );
                return Ok(HttpJsonEnvelope::new(
                    HttpStatus::NotFound,
                    serde_json::json!({ "error": message }),
                ));
            }
        };

        self.logger.info(&format!(
            "🤖 [AI Fertilize] Querying fertilize info for update: {fertilize_name} (ID: {})",
            fertilize_record.id.unwrap_or(fertilize_id)
        ));

        let fertilize_info = self
            .fertilize_ai_query_gateway
            .fetch_for_update(fertilize_id, fertilize_name)?;

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
            return Ok(HttpJsonEnvelope::new(
                status,
                serde_json::json!({ "error": error_msg }),
            ));
        }

        let fertilize_data = match normalize_fertilize_payload(&fertilize_info) {
            Some(data) => data,
            None => {
                let message = self
                    .translator
                    .t("api.errors.fertilizes.invalid_payload", &opts);
                return Ok(HttpJsonEnvelope::new(
                    HttpStatus::UnprocessableEntity,
                    serde_json::json!({ "error": message }),
                ));
            }
        };

        self.logger.info(&format!(
            "🔄 [AI Fertilize] Updating fertilize#{} with latest data from agrr",
            fertilize_record.id.unwrap_or(fertilize_id)
        ));

        let attrs = attrs_from_payload(&fertilize_data);
        let result = self
            .update_interactor
            .call(fertilize_record.id.unwrap_or(fertilize_id), attrs);

        if !result.success {
            let error = result.error.unwrap_or_else(|| "unknown error".into());
            self.logger
                .error(&format!("❌ [AI Fertilize] Failed to update: {error}"));
            return Ok(HttpJsonEnvelope::new(
                HttpStatus::UnprocessableEntity,
                serde_json::json!({ "error": error }),
            ));
        }

        let fertilize_entity = result.data.expect("success implies data");
        self.logger.info(&format!(
            "✅ [AI Fertilize] Updated fertilize#{}: {}",
            fertilize_entity.id.unwrap_or(0),
            fertilize_entity.name
        ));

        let mut msg_opts = TranslateOptions::new();
        msg_opts.insert("name".into(), fertilize_entity.name.clone());
        let message = self
            .translator
            .t("api.messages.fertilizes.updated_by_ai", &msg_opts);

        Ok(HttpJsonEnvelope::new(
            HttpStatus::Ok,
            serde_json::json!({
                "success": true,
                "fertilize_id": fertilize_entity.id,
                "fertilize_name": fertilize_entity.name,
                "n": fertilize_entity.n,
                "p": fertilize_entity.p,
                "k": fertilize_entity.k,
                "description": fertilize_entity.description,
                "package_size": fertilize_entity.package_size,
                "is_reference": fertilize_entity.is_reference,
                "message": message,
            }),
        ))
    }

    fn load_authorized_fertilize(
        &self,
        user: &crate::shared::user::User,
        fertilize_id: i64,
    ) -> Option<crate::fertilize::entities::FertilizeEntity> {
        let access_filter = fertilize_policy::record_access_filter(*user);
        let entity = self.fertilize_gateway.find_by_id(fertilize_id).ok()?;
        reference_record_authorization::assert_edit_allowed(&access_filter, &entity).ok()?;
        Some(entity)
    }
}

fn attrs_from_payload(data: &std::collections::BTreeMap<String, serde_json::Value>) -> AttrMap {
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
