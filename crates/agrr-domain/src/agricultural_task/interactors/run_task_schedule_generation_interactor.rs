//! Orchestrates task schedule generation with sync state transitions.

use crate::agricultural_task::constants::task_schedule_sync_states as sync_state;
use crate::agricultural_task::dtos::{
    RunTaskScheduleGenerationInput, RunTaskScheduleGenerationOutcome, TaskScheduleGenerateInput,
    UpdateTaskScheduleSyncStateInput,
};
use crate::agricultural_task::ports::{
    TaskScheduleGenerateInputPort, TaskScheduleSyncStateUpdateInputPort,
};
use crate::agricultural_task::task_schedule_sync_error_i18n_key;

pub struct RunTaskScheduleGenerationInteractor<'a, S, G> {
    sync_state_update: &'a S,
    task_schedule_generate: &'a G,
}

impl<'a, S, G> RunTaskScheduleGenerationInteractor<'a, S, G>
where
    S: TaskScheduleSyncStateUpdateInputPort,
    G: TaskScheduleGenerateInputPort,
{
    pub fn new(sync_state_update: &'a S, task_schedule_generate: &'a G) -> Self {
        Self {
            sync_state_update,
            task_schedule_generate,
        }
    }

    pub fn call(
        &self,
        input: RunTaskScheduleGenerationInput,
    ) -> Result<RunTaskScheduleGenerationOutcome, Box<dyn std::error::Error + Send + Sync>> {
        self.sync_state_update.call(UpdateTaskScheduleSyncStateInput {
            plan_id: input.plan_id,
            sync_state: sync_state::GENERATING,
            sync_error: None,
        })?;

        match self
            .task_schedule_generate
            .call(TaskScheduleGenerateInput::new(input.plan_id))
        {
            Ok(()) => {
                self.sync_state_update.call(UpdateTaskScheduleSyncStateInput {
                    plan_id: input.plan_id,
                    sync_state: sync_state::READY,
                    sync_error: None,
                })?;
                Ok(RunTaskScheduleGenerationOutcome::Ready)
            }
            Err(err) => {
                let i18n_key = task_schedule_sync_error_i18n_key(err.as_ref());
                self.sync_state_update.call(UpdateTaskScheduleSyncStateInput {
                    plan_id: input.plan_id,
                    sync_state: sync_state::FAILED,
                    sync_error: Some(&i18n_key),
                })?;
                Ok(RunTaskScheduleGenerationOutcome::Failed { i18n_key })
            }
        }
    }
}

#[cfg(test)]
mod interactors_run_task_schedule_generation_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/agricultural_task/interactors_run_task_schedule_generation_interactor_test.rs"
    ));
}
