//! Ruby: `Domain::CultivationPlan::Interactors::PublicPlanSaveInteractor`

use crate::cultivation_plan::dtos::{
    PublicPlanSaveFailure, PublicPlanSaveFromSessionOutput, PublicPlanSaveInput,
    PublicPlanSaveSessionData, PublicPlanSaveWorkspace,
};
use crate::cultivation_plan::gateways::{PublicPlanSaveReadGateway, PublicPlanSaveTxnGateway};
use crate::cultivation_plan::mappers::session_data_from_snapshots;
use crate::cultivation_plan::ports::{
    PublicPlanSaveFromSessionOutputPort, PublicPlanSavePersistencePort,
};
use crate::farm::gateways::FarmGateway;
use crate::shared::exceptions::{InvalidTaskScheduleItemError, RecordInvalidError};
use crate::shared::ports::{LoggerPort, TranslatorPort};

pub struct PublicPlanSaveInteractor<'a, O, TX, R, F, P, L, T> {
    output_port: &'a mut O,
    txn_gateway: &'a TX,
    read_gateway: &'a R,
    farm_gateway: &'a F,
    persistence_port: &'a P,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, O, TX, R, F, P, L, T> PublicPlanSaveInteractor<'a, O, TX, R, F, P, L, T>
where
    O: PublicPlanSaveFromSessionOutputPort,
    TX: PublicPlanSaveTxnGateway,
    R: PublicPlanSaveReadGateway,
    F: FarmGateway,
    P: PublicPlanSavePersistencePort,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        txn_gateway: &'a TX,
        read_gateway: &'a R,
        farm_gateway: &'a F,
        persistence_port: &'a P,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            output_port,
            txn_gateway,
            read_gateway,
            farm_gateway,
            persistence_port,
            logger,
            translator,
        }
    }

    pub fn call(
        &mut self,
        input: &PublicPlanSaveInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if !input.plan_id_present() && input.session_data.is_none() {
            self.output_port.on_failure(PublicPlanSaveFailure::new(
                PublicPlanSaveFailure::KIND_MISSING_PLAN_ID,
                None,
            ));
            return Ok(());
        }

        let session_data = match self.resolve_session_data(input) {
            Some(data) => data,
            None => {
                self.output_port.on_failure(PublicPlanSaveFailure::new(
                    PublicPlanSaveFailure::KIND_PLAN_NOT_FOUND,
                    None,
                ));
                return Ok(());
            }
        };

        let workspace = PublicPlanSaveWorkspace {
            user_id: input.user_id,
            session_data,
        };

        match self.persist_workspace(&workspace) {
            Ok(output) if output.success => {
                self.output_port.on_success();
                Ok(())
            }
            Ok(output) => {
                let fallback = self
                    .translator
                    .t("public_plans.save.error", &Default::default());
                let text = output
                    .error_message
                    .filter(|m| !m.trim().is_empty())
                    .unwrap_or(fallback);
                self.output_port.on_failure(PublicPlanSaveFailure::new(
                    PublicPlanSaveFailure::KIND_SAVE_FAILED,
                    Some(text),
                ));
                Ok(())
            }
            Err(err) if err.downcast_ref::<InvalidTaskScheduleItemError>().is_some() => {
                let _e = err.downcast_ref::<InvalidTaskScheduleItemError>().unwrap();
                self.logger.error(
                    "❌ [PublicPlanSaveInteractor] InvalidTaskScheduleItem",
                );
                self.output_port.on_failure(PublicPlanSaveFailure::new(
                    PublicPlanSaveFailure::KIND_UNEXPECTED,
                    Some(self.translator.t("public_plans.save.error", &Default::default())),
                ));
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                self.logger.error(&format!(
                    "❌ [PublicPlanSaveInteractor] RecordInvalid: {invalid}"
                ));
                self.output_port.on_failure(PublicPlanSaveFailure::new(
                    PublicPlanSaveFailure::KIND_SAVE_FAILED,
                    Some(invalid.to_string()),
                ));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }

    fn persist_workspace(
        &self,
        workspace: &PublicPlanSaveWorkspace,
    ) -> Result<PublicPlanSaveFromSessionOutput, Box<dyn std::error::Error + Send + Sync>> {
        self.txn_gateway
            .within_transaction(|| self.persistence_port.execute_save(workspace))
    }

    fn resolve_session_data(
        &self,
        input: &PublicPlanSaveInput,
    ) -> Option<PublicPlanSaveSessionData> {
        if let Some(session_data) = &input.session_data {
            return Some(session_data.clone());
        }

        let plan_id = input.plan_id?;
        let header = self.read_gateway.find_header(plan_id).ok().and_then(|h| h)?;
        let farm_id = header.farm_id?;
        self.farm_gateway.find_by_id(farm_id).ok()?;
        let field_rows = self.read_gateway.list_field_rows(plan_id).ok()?;
        Some(session_data_from_snapshots(&header, &field_rows))
    }
}

#[cfg(test)]
mod interactors_public_plan_save_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_public_plan_save_interactor_test.rs"));
}
