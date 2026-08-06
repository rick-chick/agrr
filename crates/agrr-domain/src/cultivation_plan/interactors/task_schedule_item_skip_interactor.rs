//! Ruby: `Domain::CultivationPlan::Interactors::TaskScheduleItemSkipInteractor`

use crate::cultivation_plan::gateways::{CultivationPlanGateway, TaskScheduleItemMutationGateway};
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::ports::TaskScheduleItemMutationOutputPort;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserOrganizationScopeGateway;
use crate::shared::org_scope::member_organization_ids;
use crate::shared::ports::ClockPort;
use crate::shared::validation::{from_errors, ErrorsInput};

pub struct TaskScheduleItemSkipInteractor<'a, O, P, G, C, S> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    gateway: &'a G,
    clock: &'a C,
    scope_gateway: &'a S,
}

impl<'a, O, P, G, C, S> TaskScheduleItemSkipInteractor<'a, O, P, G, C, S>
where
    O: TaskScheduleItemMutationOutputPort,
    P: CultivationPlanGateway,
    G: TaskScheduleItemMutationGateway,
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

    pub fn call_skip(
        &mut self,
        user_id: i64,
        plan_id: i64,
        item_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let org_ids = member_organization_ids(self.scope_gateway, user_id)?;
        if !task_schedule_private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id, &org_ids) {
            self.output_port.on_not_found();
            return Ok(());
        }

        let payload = self
            .gateway
            .skip_item_for_plan(plan_id, item_id, self.clock.now())?;
        self.output_port.on_success(payload);
        Ok(())
    }

    pub fn call_unskip(
        &mut self,
        user_id: i64,
        plan_id: i64,
        item_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let org_ids = member_organization_ids(self.scope_gateway, user_id)?;
        if !task_schedule_private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id, &org_ids) {
            self.output_port.on_not_found();
            return Ok(());
        }

        let payload = self.gateway.unskip_item_for_plan(plan_id, item_id)?;
        self.output_port.on_success(payload);
        Ok(())
    }

    pub fn call_skip_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        item_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.call_rescuing(|this| this.call_skip(user_id, plan_id, item_id))
    }

    pub fn call_unskip_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        item_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.call_rescuing(|this| this.call_unskip(user_id, plan_id, item_id))
    }

    fn call_rescuing(
        &mut self,
        invoke: impl FnOnce(&mut Self) -> Result<(), Box<dyn std::error::Error + Send + Sync>>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match invoke(self) {
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
mod interactors_task_schedule_item_skip_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_task_schedule_item_skip_interactor_test.rs"));
}
