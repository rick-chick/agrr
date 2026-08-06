//! Ruby: `Domain::CultivationPlan::Interactors::RegenerateTaskScheduleInteractor`

use crate::cultivation_plan::dtos::RegenerateTaskScheduleInput;
use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::ports::{
    RegenerateTaskScheduleOutputPort, TaskScheduleRegenEnqueuePort,
};
use crate::shared::gateways::UserOrganizationScopeGateway;
use crate::shared::org_scope::member_organization_ids;

pub struct RegenerateTaskScheduleInteractor<'a, O, P, E, S> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    enqueue_port: &'a E,
    scope_gateway: &'a S,
}

impl<'a, O, P, E, S> RegenerateTaskScheduleInteractor<'a, O, P, E, S>
where
    O: RegenerateTaskScheduleOutputPort,
    P: CultivationPlanGateway,
    E: TaskScheduleRegenEnqueuePort,
    S: UserOrganizationScopeGateway,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a P,
        enqueue_port: &'a E,
        scope_gateway: &'a S,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            enqueue_port,
            scope_gateway,
        }
    }

    pub fn call(
        &mut self,
        input: RegenerateTaskScheduleInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let org_ids = member_organization_ids(self.scope_gateway, input.user_id)?;
        if !task_schedule_private_plan_access::access_allowed(
            self.plan_gateway, input.plan_id, input.user_id,
            &org_ids,
        ) {
            self.output_port.on_not_found();
            return Ok(());
        }

        self.enqueue_port.enqueue_immediate(input.plan_id)?;
        self.output_port.on_success();
        Ok(())
    }
}

#[cfg(test)]
mod interactors_regenerate_task_schedule_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/interactors_regenerate_task_schedule_interactor_test.rs"
    ));
}
