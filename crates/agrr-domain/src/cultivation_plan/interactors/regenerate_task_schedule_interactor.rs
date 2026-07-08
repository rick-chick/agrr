//! Ruby: `Domain::CultivationPlan::Interactors::RegenerateTaskScheduleInteractor`

use crate::cultivation_plan::dtos::RegenerateTaskScheduleInput;
use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::ports::{
    RegenerateTaskScheduleOutputPort, TaskScheduleRegenEnqueuePort,
};

pub struct RegenerateTaskScheduleInteractor<'a, O, P, E> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    enqueue_port: &'a E,
}

impl<'a, O, P, E> RegenerateTaskScheduleInteractor<'a, O, P, E>
where
    O: RegenerateTaskScheduleOutputPort,
    P: CultivationPlanGateway,
    E: TaskScheduleRegenEnqueuePort,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a P,
        enqueue_port: &'a E,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            enqueue_port,
        }
    }

    pub fn call(
        &mut self,
        input: RegenerateTaskScheduleInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if !task_schedule_private_plan_access::access_allowed(
            self.plan_gateway,
            input.plan_id,
            input.user_id,
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
