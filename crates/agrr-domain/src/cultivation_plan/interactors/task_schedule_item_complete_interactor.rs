//! Ruby: `Domain::CultivationPlan::Interactors::TaskScheduleItemCompleteInteractor`

use std::collections::BTreeMap;

use serde_json::Value;

use crate::cultivation_plan::dtos::TaskScheduleItemCompleteInput;
use crate::cultivation_plan::gateways::{CultivationPlanGateway, TaskScheduleItemMutationGateway};
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::ports::TaskScheduleItemMutationOutputPort;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::ports::ClockPort;
use crate::shared::validation::{from_errors, ErrorsInput};

pub struct TaskScheduleItemCompleteInteractor<'a, O, P, G, C> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    gateway: &'a G,
    clock: &'a C,
}

impl<'a, O, P, G, C> TaskScheduleItemCompleteInteractor<'a, O, P, G, C>
where
    O: TaskScheduleItemMutationOutputPort,
    P: CultivationPlanGateway,
    G: TaskScheduleItemMutationGateway,
    C: ClockPort,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a P,
        gateway: &'a G,
        clock: &'a C,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            gateway,
            clock,
        }
    }

    pub fn call(
        &mut self,
        user_id: i64,
        plan_id: i64,
        item_id: i64,
        completion_params: &BTreeMap<String, Value>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if !task_schedule_private_plan_access::access_allowed(self.plan_gateway, plan_id, user_id) {
            self.output_port.on_not_found();
            return Ok(());
        }

        let input =
            TaskScheduleItemCompleteInput::from_completion_params(completion_params, self.clock)?;
        let payload = self.gateway.complete_item_for_plan(
            plan_id,
            item_id,
            input.actual_date,
            input.actual_notes.as_deref(),
            input.completed_at,
        )?;
        self.output_port.on_success(payload);
        Ok(())
    }

    pub fn call_rescuing(
        &mut self,
        user_id: i64,
        plan_id: i64,
        item_id: i64,
        completion_params: &BTreeMap<String, Value>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.call(user_id, plan_id, item_id, completion_params) {
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
mod interactors_task_schedule_item_complete_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_task_schedule_item_complete_interactor_test.rs"));
}
