//! Ruby: `Domain::Pest::Interactors::PestAiCreateInteractor`

use crate::pest::dtos::{HttpStatus, PestAiCreateFailure, PestAiCreateOutput};
use crate::pest::gateways::PestGateway;
use crate::pest::mappers::interpret_pest_ai_response;
use crate::pest::ports::{
    PestAiCreateInteractorPort, PestAiCreateOutputPort, PestAiUpdateInteractorPort,
};
use crate::shared::attr::{attr_map_from_pairs, AttrMap, AttrValue};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pest_policy;
use crate::shared::ports::logger_port::LoggerPort;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use serde_json::Value;

/// Ruby edge runner: associates affected crops after create/update.
pub trait AssociateAffectedCropsRunner: Send + Sync {
    fn call(
        &self,
        pest_id: i64,
        affected_crops: &[Value],
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>>;
}

/// Minimal AI query surface for pest create.
pub trait PestAiQueryGateway: Send + Sync {
    fn fetch_pest_json(
        &self,
        pest_name: &str,
        affected_crops: &[Value],
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;
}

pub struct PestAiCreateInteractor<'a, O, PG, AQ, CI, UI, R, U, T, L> {
    output_port: &'a mut O,
    user_id: i64,
    user_lookup: &'a U,
    pest_gateway: &'a PG,
    pest_ai_query_gateway: &'a AQ,
    create_interactor: &'a CI,
    update_interactor: &'a UI,
    associate_affected_crops_runner: &'a R,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, O, PG, AQ, CI, UI, R, U, T, L> PestAiCreateInteractor<'a, O, PG, AQ, CI, UI, R, U, T, L>
where
    O: PestAiCreateOutputPort,
    PG: PestGateway,
    AQ: PestAiQueryGateway,
    CI: PestAiCreateInteractorPort,
    UI: PestAiUpdateInteractorPort,
    R: AssociateAffectedCropsRunner,
    U: UserLookupGateway,
    T: TranslatorPort,
    L: LoggerPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        user_lookup: &'a U,
        pest_gateway: &'a PG,
        pest_ai_query_gateway: &'a AQ,
        create_interactor: &'a CI,
        update_interactor: &'a UI,
        associate_affected_crops_runner: &'a R,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            output_port,
            user_id,
            user_lookup,
            pest_gateway,
            pest_ai_query_gateway,
            create_interactor,
            update_interactor,
            associate_affected_crops_runner,
            logger,
            translator,
        }
    }

    pub fn call(
        &mut self,
        pest_name: Option<&str>,
        affected_crops: &[Value],
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let opts = TranslateOptions::default();

        if user.anonymous {
            self.output_port.on_failure(PestAiCreateFailure::new(
                HttpStatus::Unauthorized,
                self.translator.t("auth.api.login_required", &opts),
            ));
            return Ok(());
        }

        let pn = pest_name.map(str::trim).unwrap_or("");
        if pn.is_empty() {
            self.output_port.on_failure(PestAiCreateFailure::new(
                HttpStatus::BadRequest,
                self.translator.t("api.errors.pests.name_required", &opts),
            ));
            return Ok(());
        }

        self.logger
            .info(&format!("🔍 [AI Pest] Received params: name={pn}"));
        self.logger.info(&format!(
            "🔍 [AI Pest] affected_crops count: {}",
            affected_crops.len()
        ));

        self.logger
            .info(&format!("🤖 [AI Pest] Querying pest info for: {pn}"));
        let pest_info = self
            .pest_ai_query_gateway
            .fetch_pest_json(pn, affected_crops)?;
        let interpreted = interpret_pest_ai_response(&pest_info, self.translator, true);
        if let Some(failure) = interpreted.failure {
            self.output_port.on_failure(failure);
            return Ok(());
        }

        let pest_data = interpreted.pest_data.unwrap_or(Value::Null);
        let affected_crops_from_agrr = interpreted.affected_crops_from_agrr;

        let base_attrs = attrs_from_pest_data(&pest_data);
        let pest_name_key = base_attrs
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or(pn);

        let existing_pest = self
            .pest_gateway
            .find_by_name(self.user_id, pest_name_key)?;

        let (http_status, pest_entity) = if let Some(existing) = existing_pest {
            self.logger.info(&format!(
                "🔄 [AI Pest] Updating existing pest#{}: {pest_name_key}",
                existing.id
            ));
            let result = self
                .update_interactor
                .call(existing.id, base_attrs.clone());
            if !result.success {
                let error = result.error.unwrap_or_else(|| "unknown error".into());
                self.output_port.on_failure(PestAiCreateFailure::new(
                    HttpStatus::UnprocessableEntity,
                    error,
                ));
                return Ok(());
            }
            (
                HttpStatus::Ok,
                result.data.expect("success implies data"),
            )
        } else {
            self.logger
                .info(&format!("🆕 [AI Pest] Creating new pest: {pest_name_key}"));
            let mut create_attrs = base_attrs;
            for (k, v) in pest_policy::normalize_attrs_for_create(&user, AttrMap::new(), false) {
                create_attrs.insert(k, v);
            }
            let result = self.create_interactor.call(create_attrs);
            if !result.success {
                let error = result.error.unwrap_or_else(|| "unknown error".into());
                self.output_port.on_failure(PestAiCreateFailure::new(
                    HttpStatus::UnprocessableEntity,
                    error,
                ));
                return Ok(());
            }
            (
                HttpStatus::Created,
                result.data.expect("success implies data"),
            )
        };

        self.logger.info(&format!(
            "✅ [AI Pest] Saved pest#{}: {}",
            pest_entity.id, pest_entity.name
        ));

        let chosen: Vec<Value> = match &affected_crops_from_agrr {
            Some(Value::Array(arr)) if !arr.is_empty() => arr.clone(),
            _ => affected_crops.to_vec(),
        };

        if !chosen.is_empty() {
            self.logger.info(&format!(
                "🔗 [AI Pest] Starting crop association for pest#{} (count={})",
                pest_entity.id,
                chosen.len()
            ));
            self.associate_affected_crops_runner
                .call(pest_entity.id, &chosen)?;
        } else {
            self.logger
                .warn("⚠️  [AI Pest] Skipping crop association: affected_crops is empty");
        }

        let mut msg_opts = TranslateOptions::new();
        msg_opts.insert("name".into(), pest_entity.name.clone());
        let message = self
            .translator
            .t("api.messages.pests.created_by_ai", &msg_opts);

        self.output_port.on_success(PestAiCreateOutput {
            http_status,
            pest_id: pest_entity.id,
            pest_name: pest_entity.name.clone(),
            name_scientific: pest_entity.name_scientific.clone(),
            family: pest_entity.family.clone(),
            order: pest_entity.order.clone(),
            description: pest_entity.description.clone(),
            occurrence_season: pest_entity.occurrence_season.clone(),
            message,
        });
        Ok(())
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
        if let Some(s) = data.get(key).and_then(|v| v.as_str()) {
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
    if let Some(v) = data.get("control_methods") {
        if let Ok(s) = serde_json::to_string(v) {
            pairs.push(("control_methods", AttrValue::Str(s)));
        }
    }
    attr_map_from_pairs(pairs)
}

#[cfg(test)]
mod interactors_pest_ai_create_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/interactors_pest_ai_create_interactor_test.rs"));
}
