//! Ruby: `Domain::WorkRecord::Interactors::WorkRecordListInteractor`

use std::collections::BTreeMap;

use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::validation::{from_errors, ErrorsInput};
use crate::work_record::dtos::WorkRecordListInput;
use crate::work_record::gateways::WorkRecordGateway;
use crate::work_record::interactors::private_plan_access;
use crate::work_record::ports::WorkRecordListOutputPort;

pub struct WorkRecordListInteractor<'a, O, P, G> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    gateway: &'a G,
}

impl<'a, O, P, G> WorkRecordListInteractor<'a, O, P, G>
where
    O: WorkRecordListOutputPort,
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
        query: &BTreeMap<String, String>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if !private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id) {
            self.output_port.on_not_found();
            return Ok(());
        }

        let filter = WorkRecordListInput::from_query(query)?;
        let records = self.gateway.list_for_plan(plan_id, &filter)?;
        self.output_port.on_success(records);
        Ok(())
    }

    pub fn call_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        query: &BTreeMap<String, String>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(user_id, plan_id, query) {
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
mod interactors_work_record_list_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/work_record/interactors_work_record_list_interactor_test.rs"
    ));
}
