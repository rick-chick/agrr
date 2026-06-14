//! Ruby: `Domain::WorkRecord::Interactors::WorkRecordDestroyInteractor`

use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::validation::{from_errors, ErrorsInput};
use crate::work_record::gateways::WorkRecordGateway;
use crate::work_record::interactors::private_plan_access;
use crate::work_record::ports::WorkRecordDestroyOutputPort;

pub struct WorkRecordDestroyInteractor<'a, O, P, G> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    gateway: &'a G,
}

impl<'a, O, P, G> WorkRecordDestroyInteractor<'a, O, P, G>
where
    O: WorkRecordDestroyOutputPort,
    P: CultivationPlanGateway,
    G: WorkRecordGateway,
{
    pub fn new(output_port: &'a mut O, plan_gateway: &'a P, gateway: &'a G) -> Self {
        Self {
            output_port,
            plan_gateway,
            gateway,
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

        self.gateway.destroy(plan_id, record_id)?;
        self.output_port.on_success();
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
