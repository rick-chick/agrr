//! Orchestrates task schedule generation with sync state transitions.

use crate::agricultural_task::constants::task_schedule_sync_states as sync_state;
use crate::agricultural_task::dtos::{
    RunTaskScheduleGenerationInput, RunTaskScheduleGenerationOutcome, TaskScheduleGenerateInput,
    UpdateTaskScheduleSyncStateInput,
};
use crate::agricultural_task::ports::{
    TaskScheduleBlueprintEnsureInputPort, TaskScheduleGenerateInputPort,
    TaskScheduleSyncStateUpdateInputPort,
};
use crate::agricultural_task::task_schedule_sync_error::{
    task_schedule_sync_error_crop_id, task_schedule_sync_error_i18n_key,
};

pub struct RunTaskScheduleGenerationInteractor<'a, S, E, G> {
    sync_state_update: &'a S,
    blueprint_ensure: &'a E,
    task_schedule_generate: &'a G,
}

impl<'a, S, E, G> RunTaskScheduleGenerationInteractor<'a, S, E, G>
where
    S: TaskScheduleSyncStateUpdateInputPort,
    E: TaskScheduleBlueprintEnsureInputPort,
    G: TaskScheduleGenerateInputPort,
{
    pub fn new(
        sync_state_update: &'a S,
        blueprint_ensure: &'a E,
        task_schedule_generate: &'a G,
    ) -> Self {
        Self {
            sync_state_update,
            blueprint_ensure,
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
            sync_error_crop_id: None,
        })?;

        if let Err(err) = self.blueprint_ensure.ensure_for_plan(input.plan_id) {
            let i18n_key = task_schedule_sync_error_i18n_key(err.as_ref());
            self.sync_state_update.call(UpdateTaskScheduleSyncStateInput {
                plan_id: input.plan_id,
                sync_state: sync_state::FAILED,
                sync_error: Some(&i18n_key),
                sync_error_crop_id: task_schedule_sync_error_crop_id(err.as_ref()),
            })?;
            return Ok(RunTaskScheduleGenerationOutcome::Failed { i18n_key });
        }

        match self
            .task_schedule_generate
            .call(TaskScheduleGenerateInput::new(input.plan_id))
        {
            Ok(()) => {
                self.sync_state_update.call(UpdateTaskScheduleSyncStateInput {
                    plan_id: input.plan_id,
                    sync_state: sync_state::READY,
                    sync_error: None,
                    sync_error_crop_id: None,
                })?;
                Ok(RunTaskScheduleGenerationOutcome::Ready)
            }
            Err(err) => {
                let i18n_key = task_schedule_sync_error_i18n_key(err.as_ref());
                self.sync_state_update.call(UpdateTaskScheduleSyncStateInput {
                    plan_id: input.plan_id,
                    sync_state: sync_state::FAILED,
                    sync_error: Some(&i18n_key),
                    sync_error_crop_id: task_schedule_sync_error_crop_id(err.as_ref()),
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
