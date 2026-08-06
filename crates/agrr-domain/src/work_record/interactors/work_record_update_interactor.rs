//! Ruby: `Domain::WorkRecord::Interactors::WorkRecordUpdateInteractor`

use std::collections::BTreeMap;

use serde_json::Value;

use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserOrganizationScopeGateway;
use crate::shared::org_scope::member_organization_ids;
use crate::shared::ports::ClockPort;
use crate::shared::validation::{from_errors, ErrorsInput};
use crate::work_record::dtos::WorkRecordUpdateInput;
use crate::work_record::gateways::WorkRecordGateway;
use crate::work_record::interactors::private_plan_access;
use crate::work_record::ports::WorkRecordUpdateOutputPort;

pub struct WorkRecordUpdateInteractor<'a, O, P, G, C, S> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    gateway: &'a G,
    clock: &'a C,
    scope_gateway: &'a S,
}

impl<'a, O, P, G, C, S> WorkRecordUpdateInteractor<'a, O, P, G, C, S>
where
    O: WorkRecordUpdateOutputPort,
    P: CultivationPlanGateway,
    G: WorkRecordGateway,
    C: ClockPort,
    S: UserOrganizationScopeGateway,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a P,
        gateway: &'a G,
        clock: &'a C,
        scope_gateway: &'a S,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            gateway,
            clock,
            scope_gateway,
        }
    }

    pub fn call(
        &mut self,
        user_id: i64,
        plan_id: i64,
        record_id: i64,
        params: &BTreeMap<String, Value>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let org_ids = member_organization_ids(self.scope_gateway, user_id)?;
        if !private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id, &org_ids) {
            self.output_port.on_not_found();
            return Ok(());
        }

        let input = WorkRecordUpdateInput::from_params(params, self.clock)?;
        let record = self
            .gateway
            .update(plan_id, record_id, &input, self.clock.now())?;
        self.output_port.on_success(record);
        Ok(())
    }

    pub fn call_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        record_id: i64,
        params: &BTreeMap<String, Value>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(user_id, plan_id, record_id, params) {
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
mod interactors_work_record_update_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/work_record/interactors_work_record_update_interactor_test.rs"
    ));
}
