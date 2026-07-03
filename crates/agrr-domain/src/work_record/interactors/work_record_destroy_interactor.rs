//! Ruby: `Domain::WorkRecord::Interactors::WorkRecordDestroyInteractor`

use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::validation::{from_errors, ErrorsInput};
use crate::work_record::dtos::WorkRecordDestroyOutput;
use crate::work_record::gateways::{WorkRecordDestroyGatewayOutcome, WorkRecordGateway};
use crate::work_record::interactors::private_plan_access;
use crate::work_record::ports::{DestroyFailure, WorkRecordDestroyOutputPort};

pub struct WorkRecordDestroyInteractor<'a, O, P, G, T> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    gateway: &'a G,
    translator: &'a T,
}

impl<'a, O, P, G, T> WorkRecordDestroyInteractor<'a, O, P, G, T>
where
    O: WorkRecordDestroyOutputPort,
    P: CultivationPlanGateway,
    G: WorkRecordGateway,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a P,
        gateway: &'a G,
        translator: &'a T,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            gateway,
            translator,
        }
    }

    pub fn call(
        &mut self,
        user_id: i64,
        plan_id: i64,
        record_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if !private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id) {
            self.output_port.on_not_found();
            return Ok(());
        }

        let record = match self.gateway.find_for_plan(plan_id, record_id) {
            Ok(record) => record,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_not_found();
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        let mut toast_opts = TranslateOptions::new();
        toast_opts.insert("name".into(), record.name.clone());
        let toast = self
            .translator
            .t("plans.work_records.undo.toast", &toast_opts);

        match self.gateway.destroy(plan_id, record_id, user_id, &toast)? {
            WorkRecordDestroyGatewayOutcome::Success { undo } => {
                self.output_port
                    .on_success(WorkRecordDestroyOutput::new(undo));
            }
            WorkRecordDestroyGatewayOutcome::Failure(error) => {
                self.output_port
                    .on_failure(DestroyFailure::Error(error));
            }
        }
        Ok(())
    }

    pub fn call_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        record_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(user_id, plan_id, record_id) {
            Ok(()) => Ok(()),
            Err(err) if err.downcast_ref::<RecordInvalidError>().is_some() => {
                let invalid = err.downcast_ref::<RecordInvalidError>().unwrap();
                self.output_port.on_record_invalid(
                    from_errors(ErrorsInput::ValidationErrors(
                        invalid.errors.as_ref().expect("record invalid"),
                    )),
                    &invalid.to_string(),
                );
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_not_found();
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

#[cfg(test)]
mod interactors_work_record_destroy_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/work_record/interactors_work_record_destroy_interactor_test.rs"
    ));
}
