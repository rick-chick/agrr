// Tests for `interactors/run_task_schedule_generation_interactor.rs`.

use std::sync::{Arc, Mutex};

use crate::agricultural_task::constants::task_schedule_sync_states;
use crate::agricultural_task::dtos::{
    RunTaskScheduleGenerationInput, RunTaskScheduleGenerationOutcome, TaskScheduleGenerateInput,
    UpdateTaskScheduleSyncStateInput,
};
use crate::agricultural_task::interactors::RunTaskScheduleGenerationInteractor;
use crate::agricultural_task::ports::{
    TaskScheduleGenerateInputPort, TaskScheduleSyncStateUpdateInputPort,
};
use crate::agricultural_task::task_schedule_sync_error::TaskScheduleSyncError;
use crate::agricultural_task::task_schedule_sync_error_keys as sync_errors;

struct SpySyncUpdate {
    calls: Arc<Mutex<Vec<(i64, String, Option<String>)>>>,
}

impl TaskScheduleSyncStateUpdateInputPort for SpySyncUpdate {
    fn call(
        &self,
        input: UpdateTaskScheduleSyncStateInput<'_>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.calls.lock().expect("lock").push((
            input.plan_id,
            input.sync_state.to_string(),
            input.sync_error.map(str::to_string),
        ));
        Ok(())
    }
}

struct StubGenerate {
    outcome: GenerateOutcome,
    calls: Arc<Mutex<Vec<i64>>>,
}

enum GenerateOutcome {
    Ok,
    AgrrUnavailable,
}

impl TaskScheduleGenerateInputPort for StubGenerate {
    fn call(
        &self,
        input: TaskScheduleGenerateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.calls.lock().expect("lock").push(input.cultivation_plan_id);
        match self.outcome {
            GenerateOutcome::Ok => Ok(()),
            GenerateOutcome::AgrrUnavailable => Err(Box::new(TaskScheduleSyncError::new(
                sync_errors::AGRR_UNAVAILABLE,
                "daemon unavailable",
            ))),
        }
    }
}

#[test]
fn run_task_schedule_generation_transitions_to_ready_on_success() {
    let sync_calls = Arc::new(Mutex::new(Vec::new()));
    let generate_calls = Arc::new(Mutex::new(Vec::new()));
    let sync = SpySyncUpdate {
        calls: sync_calls.clone(),
    };
    let generate = StubGenerate {
        outcome: GenerateOutcome::Ok,
        calls: generate_calls.clone(),
    };
    let interactor = RunTaskScheduleGenerationInteractor::new(&sync, &generate);

    let outcome = interactor
        .call(RunTaskScheduleGenerationInput::new(42))
        .expect("orchestrator call");

    assert_eq!(outcome, RunTaskScheduleGenerationOutcome::Ready);
    assert_eq!(*generate_calls.lock().expect("lock"), vec![42]);
    assert_eq!(
        *sync_calls.lock().expect("lock"),
        vec![
            (
                42,
                task_schedule_sync_states::GENERATING.to_string(),
                None
            ),
            (42, task_schedule_sync_states::READY.to_string(), None)
        ]
    );
}

#[test]
fn run_task_schedule_generation_transitions_to_failed_with_i18n_key() {
    let sync_calls = Arc::new(Mutex::new(Vec::new()));
    let sync = SpySyncUpdate {
        calls: sync_calls.clone(),
    };
    let generate = StubGenerate {
        outcome: GenerateOutcome::AgrrUnavailable,
        calls: Arc::new(Mutex::new(Vec::new())),
    };
    let interactor = RunTaskScheduleGenerationInteractor::new(&sync, &generate);

    let outcome = interactor
        .call(RunTaskScheduleGenerationInput::new(7))
        .expect("orchestrator call");

    assert_eq!(
        outcome,
        RunTaskScheduleGenerationOutcome::Failed {
            i18n_key: sync_errors::AGRR_UNAVAILABLE.to_string()
        }
    );
    assert_eq!(
        sync_calls.lock().expect("lock").last(),
        Some(&(
            7,
            task_schedule_sync_states::FAILED.to_string(),
            Some(sync_errors::AGRR_UNAVAILABLE.to_string())
        ))
    );
}
