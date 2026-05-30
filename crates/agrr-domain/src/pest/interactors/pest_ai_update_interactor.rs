//! Ruby: `Domain::Pest::Interactors::PestAiUpdateInteractor`

use crate::pest::dtos::{HttpJsonEnvelope, HttpStatus};
use crate::pest::entities::PestEntity;
use crate::pest::gateways::PestGateway;
use crate::pest::interactors::pest_ai_create_interactor::PestAiQueryGateway;
use crate::pest::mappers::interpret_pest_ai_response;
use crate::pest::ports::PestAiUpdateInteractorPort;
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
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
mod interactors_pest_ai_update_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/interactors_pest_ai_update_interactor_test.rs"));
}
