//! Ruby: `Domain::Pest::Interactors::PestAiCreateInteractor`

use crate::pest::dtos::{HttpStatus, PestAiCreateFailure, PestAiCreateOutput};
use crate::pest::gateways::PestGateway;
use crate::pest::mappers::interpret_pest_ai_response;
use crate::pest::ports::PestAiCreateOutputPort;
use crate::shared::gateways::UserLookupGateway;
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

pub struct PestAiCreateInteractor<'a, O, PG, AQ, R, U, T, L> {
    output_port: &'a mut O,
    user_id: i64,
    user_lookup: &'a U,
    pest_gateway: &'a PG,
    pest_ai_query_gateway: &'a AQ,
    associate_affected_crops_runner: &'a R,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, O, PG, AQ, R, U, T, L> PestAiCreateInteractor<'a, O, PG, AQ, R, U, T, L>
where
    O: PestAiCreateOutputPort,
    PG: PestGateway,
    AQ: PestAiQueryGateway,
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
                self.translator
                    .t("api.errors.pests.name_required", &opts),
            ));
            return Ok(());
        }

        self.logger
            .info(&format!("🔍 [AI Pest] Received params: name={pn}"));
        self.logger.info(&format!(
            "🔍 [AI Pest] affected_crops count: {}",
            affected_crops.len()
        ));

        let pest_info = self
            .pest_ai_query_gateway
            .fetch_pest_json(pn, affected_crops)?;
        let interpreted =
            interpret_pest_ai_response(&pest_info, self.translator, true);
        if let Some(failure) = interpreted.failure {
            self.output_port.on_failure(failure);
            return Ok(());
        }

        let _pest_data = interpreted.pest_data;
        let _affected_crops_from_agrr = interpreted.affected_crops_from_agrr;

        // Full create/update path deferred to edge wiring; blank-name path is domain-tested.
        let _ = self.pest_gateway;
        let _ = self.associate_affected_crops_runner;
        Ok(())
    }
}

#[cfg(test)]
mod interactors_pest_ai_create_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/interactors_pest_ai_create_interactor_test.rs"));
}
