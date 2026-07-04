//! Task schedule generation orchestration (optimization chain + debounced regen).

use std::sync::Arc;
use std::time::Duration;

use crate::adapters::SystemClock;
use crate::cable::CableHub;
use crate::jobs::JobStep;
use crate::optimization_chain_phase::{advance_phase, plan_still_optimizing};
use crate::state::AppState;
use agrr_adapters_agrr::TaskScheduleProgressAgrrGateway;
use agrr_adapters_sqlite::{
    SqlitePool, TaskScheduleGenerationReadSqliteGateway,
    TaskScheduleGenerationTransactionSqliteGateway, TaskScheduleSqliteGateway,
    TaskScheduleSyncStateSqliteGateway,
};
use agrr_domain::agricultural_task::constants::task_schedule_sync_states as sync_state;
use agrr_domain::agricultural_task::dtos::{
    RunTaskScheduleGenerationInput, RunTaskScheduleGenerationOutcome,
    UpdateTaskScheduleSyncStateInput,
};
use agrr_domain::agricultural_task::interactors::{
    RunTaskScheduleGenerationInteractor, TaskScheduleEnsureBlueprintsInteractor,
    TaskScheduleGenerateInteractor, UpdateTaskScheduleSyncStateInteractor,
};
use agrr_domain::agricultural_task::ports::TaskScheduleSyncBroadcastPort;
use agrr_domain::cultivation_plan::dtos::CultivationPlanPhaseName;
use serde_json::json;
use tracing::info;

const REGEN_DEBOUNCE_SECS: u64 = 3;

struct CableTaskScheduleSyncBroadcast {
    hub: Arc<CableHub>,
}

impl TaskScheduleSyncBroadcastPort for CableTaskScheduleSyncBroadcast {
    fn broadcast_sync_state(
        &self,
        plan_id: i64,
        sync_state: &str,
        sync_error: Option<&str>,
        sync_error_crop_id: Option<i64>,
    ) {
        self.hub.broadcast_plan_message(
            plan_id,
            json!({
                "type": "task_schedule_sync",
                "task_schedule_sync_state": sync_state,
                "task_schedule_sync_error": sync_error,
                "task_schedule_sync_error_crop_id": sync_error_crop_id,
            }),
        );
    }
}

struct TaskScheduleSyncInteractorBundle {
    gateway: TaskScheduleSyncStateSqliteGateway,
    broadcast: CableTaskScheduleSyncBroadcast,
}

impl TaskScheduleSyncInteractorBundle {
    fn new(state: &AppState, pool: SqlitePool) -> Self {
        Self {
            gateway: TaskScheduleSyncStateSqliteGateway::new(pool),
            broadcast: CableTaskScheduleSyncBroadcast {
                hub: state.cable_hub.clone(),
            },
        }
    }

    fn interactor(
        &self,
    ) -> UpdateTaskScheduleSyncStateInteractor<
        '_,
        TaskScheduleSyncStateSqliteGateway,
        CableTaskScheduleSyncBroadcast,
    > {
        UpdateTaskScheduleSyncStateInteractor::new(&self.gateway, &self.broadcast)
    }

    fn call(
        &self,
        input: UpdateTaskScheduleSyncStateInput<'_>,
    ) -> Result<(), String> {
        self.interactor().call(input).map_err(|e| e.to_string())
    }
}

fn apply_task_schedule_sync_state(
    state: &AppState,
    plan_id: i64,
    sync_state_value: &str,
    sync_error: Option<&str>,
    sync_error_crop_id: Option<i64>,
) -> Result<(), String> {
    let sync = TaskScheduleSyncInteractorBundle::new(state, state.sqlite.clone());
    sync.call(UpdateTaskScheduleSyncStateInput {
        plan_id,
        sync_state: sync_state_value,
        sync_error,
        sync_error_crop_id,
    })
}

fn mark_task_schedule_stale(state: &AppState, plan_id: i64) {
    let _ = apply_task_schedule_sync_state(state, plan_id, sync_state::STALE, None, None);
}

fn bump_regen_token(state: &AppState, plan_id: i64) -> u64 {
    let mut tokens = state
        .task_schedule_regen_tokens
        .lock()
        .expect("task_schedule_regen_tokens lock");
    let entry = tokens.entry(plan_id).or_insert(0);
    *entry += 1;
    *entry
}

fn clear_regen_token_if_current(state: &AppState, plan_id: i64, generation: u64) {
    let mut tokens = state
        .task_schedule_regen_tokens
        .lock()
        .expect("task_schedule_regen_tokens lock");
    if tokens.get(&plan_id).copied() == Some(generation) {
        tokens.remove(&plan_id);
    }
}

fn run_task_schedule_generation(state: &AppState, plan_id: i64) -> Result<(), String> {
    let pool = state.sqlite.clone();
    let sync = TaskScheduleSyncInteractorBundle::new(state, pool.clone());

    let read_gateway = Arc::new(TaskScheduleGenerationReadSqliteGateway::new(
        pool.clone(),
        state.predicted_weather.store.clone(),
    ));
    let progress_gateway = TaskScheduleProgressAgrrGateway::from_env(read_gateway.clone());
    let task_schedule_gateway = TaskScheduleSqliteGateway::new(pool.clone());
    let cultivation_plan_gateway = TaskScheduleGenerationTransactionSqliteGateway::new();
    let clock = SystemClock;
    let generate_interactor = TaskScheduleGenerateInteractor::new(
        &progress_gateway,
        &task_schedule_gateway,
        &clock,
        &cultivation_plan_gateway,
        read_gateway.as_ref(),
    );

    let ensure_interactor = TaskScheduleEnsureBlueprintsInteractor::new();

    let sync_interactor = sync.interactor();
    let orchestrator = RunTaskScheduleGenerationInteractor::new(
        &sync_interactor,
        &ensure_interactor,
        &generate_interactor,
    );

    match orchestrator.call(RunTaskScheduleGenerationInput::new(plan_id)) {
        Ok(RunTaskScheduleGenerationOutcome::Ready) => {
            info!(plan_id, "task schedule generation succeeded");
            Ok(())
        }
        Ok(RunTaskScheduleGenerationOutcome::Failed { i18n_key }) => {
            eprintln!(
                "task schedule generation failed plan_id={plan_id} key={i18n_key}"
            );
            Ok(())
        }
        Err(err) => Err(err.to_string()),
    }
}

/// Optimization chain step: advance phase, generate, never abort the chain on generation failure.
pub fn run_task_schedule_generation_step(
    state: &AppState,
    plan_id: i64,
    channel: &str,
) -> Result<(), String> {
    if !plan_still_optimizing(&state.sqlite, plan_id) {
        return Ok(());
    }
    let _ = advance_phase(
        state,
        plan_id,
        channel,
        CultivationPlanPhaseName::PhaseTaskScheduleGenerating,
        None,
    );
    run_task_schedule_generation(state, plan_id)
}

pub fn enqueue_task_schedule_regen_immediate(state: &AppState, plan_id: i64) {
    let generation = bump_regen_token(state, plan_id);
    let state = state.clone();
    let dispatcher = state.task_schedule_regen_dispatcher.clone();
    dispatcher.enqueue_chain(vec![JobStep {
        name: "task_schedule_regen",
        run: Arc::new(move || {
            let state = state.clone();
            Box::pin(async move {
                let _ = run_task_schedule_generation(&state, plan_id);
                clear_regen_token_if_current(&state, plan_id, generation);
                true
            })
        }),
    }]);
}

pub fn enqueue_task_schedule_regen_debounced(state: &AppState, plan_id: i64) {
    mark_task_schedule_stale(state, plan_id);

    let generation = bump_regen_token(state, plan_id);

    let state_clone = state.clone();
    let dispatcher = state.task_schedule_regen_dispatcher.clone();
    dispatcher.enqueue_chain(vec![JobStep {
        name: "task_schedule_regen_debounce",
        run: Arc::new(move || {
            let state = state_clone.clone();
            Box::pin(async move {
                tokio::time::sleep(Duration::from_secs(REGEN_DEBOUNCE_SECS)).await;
                let current = state
                    .task_schedule_regen_tokens
                    .lock()
                    .ok()
                    .and_then(|m| m.get(&plan_id).copied())
                    .unwrap_or(0);
                if current != generation {
                    return true;
                }
                let _ = run_task_schedule_generation(&state, plan_id);
                clear_regen_token_if_current(&state, plan_id, generation);
                true
            })
        }),
    }]);
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cable::CableHub;
    use crate::test_support::{test_app_state, test_pool_with_sync_plan};
    use agrr_adapters_sqlite::{SqlitePool, TaskScheduleSyncStateSqliteGateway};
    use agrr_domain::agricultural_task::constants::task_schedule_sync_states as sync_state;
    use agrr_domain::agricultural_task::gateways::TaskScheduleSyncStateGateway;
    use std::sync::Arc;
    use std::thread;
    use std::time::{Duration, Instant};

    fn wait_until(timeout: Duration, mut condition: impl FnMut() -> bool) -> bool {
        let deadline = Instant::now() + timeout;
        while Instant::now() < deadline {
            if condition() {
                return true;
            }
            thread::sleep(Duration::from_millis(25));
        }
        false
    }

    fn sync_state(pool: &SqlitePool, plan_id: i64) -> String {
        TaskScheduleSyncStateSqliteGateway::new(pool.clone())
            .find_sync_state(plan_id)
            .expect("sync state")
    }

    fn test_app_state_with_hub(pool: SqlitePool, hub: Arc<CableHub>) -> AppState {
        let mut state = test_app_state(pool);
        state.cable_hub = hub;
        state
    }

    #[test]
    fn mark_task_schedule_stale_persists_stale_state() {
        let db = test_pool_with_sync_plan(1);
        let state = test_app_state(db.pool.clone());
        mark_task_schedule_stale(&state, 1);
        assert_eq!(sync_state(&db.pool, 1), sync_state::STALE);
    }

    #[test]
    fn mark_task_schedule_stale_broadcasts_stale_payload() {
        let db = test_pool_with_sync_plan(1);
        let hub = Arc::new(CableHub::default());
        let state = test_app_state_with_hub(db.pool.clone(), hub.clone());
        let rt = tokio::runtime::Runtime::new().expect("tokio runtime");
        let mut rx = rt.block_on(hub.subscribe_plan(1));

        mark_task_schedule_stale(&state, 1);

        let payload = rx.try_recv().expect("stale broadcast expected");
        assert!(payload.contains("\"type\":\"task_schedule_sync\""));
        assert!(payload.contains("\"task_schedule_sync_state\":\"stale\""));
        assert!(payload.contains("\"task_schedule_sync_error\":null"));
    }

    #[test]
    fn run_generation_transitions_sync_state_without_agrr_daemon() {
        let db = test_pool_with_sync_plan(42);
        let state = test_app_state(db.pool.clone());
        let _ = run_task_schedule_generation(&state, 42);
        let final_state = sync_state(&db.pool, 42);
        assert!(
            final_state == sync_state::FAILED || final_state == sync_state::READY,
            "expected failed or ready, got {final_state}"
        );
    }

    #[test]
    fn run_generation_broadcasts_failed_error_in_payload() {
        let db = test_pool_with_sync_plan(42);
        let hub = Arc::new(CableHub::default());
        let state = test_app_state_with_hub(db.pool.clone(), hub.clone());
        let rt = tokio::runtime::Runtime::new().expect("tokio runtime");
        let mut rx = rt.block_on(hub.subscribe_plan(42));

        let _ = run_task_schedule_generation(&state, 42);

        let mut saw_failed = false;
        let mut failed_payload: Option<String> = None;
        while let Ok(payload) = rx.try_recv() {
            if payload.contains("\"task_schedule_sync_state\":\"failed\"") {
                saw_failed = true;
                failed_payload = Some(payload.clone());
                assert!(
                    payload.contains("\"task_schedule_sync_error\":"),
                    "failed payload must include sync error field: {payload}"
                );
                assert!(
                    !payload.contains("\"task_schedule_sync_error\":null"),
                    "failed payload must include non-null error when generation fails: {payload}"
                );
            }
        }
        if sync_state(&db.pool, 42) == sync_state::FAILED {
            assert!(saw_failed, "failed generation should broadcast failed payload");
            let payload = failed_payload.expect("failed cable payload");
            assert!(
                payload.contains("plans.task_schedules.sync_errors."),
                "failed payload should store i18n key, not raw message: {payload}"
            );
        }
    }

    #[test]
    fn debounced_regen_coalesces_rapid_calls() {
        let db = test_pool_with_sync_plan(7);
        let state = test_app_state(db.pool.clone());
        enqueue_task_schedule_regen_debounced(&state, 7);
        enqueue_task_schedule_regen_debounced(&state, 7);
        assert_eq!(sync_state(&db.pool, 7), sync_state::STALE);
        assert!(
            wait_until(Duration::from_secs(6), || {
                let s = sync_state(&db.pool, 7);
                s == sync_state::READY || s == sync_state::FAILED
            }),
            "debounced regen should finish within timeout"
        );
    }

    #[test]
    fn immediate_regen_invalidates_pending_debounce_token() {
        let db = test_pool_with_sync_plan(7);
        let state = test_app_state(db.pool.clone());
        enqueue_task_schedule_regen_debounced(&state, 7);
        let generation_before_immediate = state
            .task_schedule_regen_tokens
            .lock()
            .expect("task_schedule_regen_tokens lock")
            .get(&7)
            .copied()
            .expect("debounced token");
        enqueue_task_schedule_regen_immediate(&state, 7);
        let generation_after_immediate = state
            .task_schedule_regen_tokens
            .lock()
            .expect("task_schedule_regen_tokens lock")
            .get(&7)
            .copied()
            .expect("immediate token bump");
        assert!(
            generation_after_immediate > generation_before_immediate,
            "immediate regen must invalidate pending debounce generation"
        );
    }

    #[test]
    fn debounced_regen_clears_token_after_completion() {
        let db = test_pool_with_sync_plan(7);
        let state = test_app_state(db.pool.clone());
        enqueue_task_schedule_regen_debounced(&state, 7);
        assert!(
            wait_until(Duration::from_secs(6), || {
                let s = sync_state(&db.pool, 7);
                s == sync_state::READY || s == sync_state::FAILED
            }),
            "debounced regen should finish within timeout"
        );
        let tokens = state
            .task_schedule_regen_tokens
            .lock()
            .expect("task_schedule_regen_tokens lock");
        assert!(
            !tokens.contains_key(&7),
            "completed debounced regen should clear token entry"
        );
    }
}