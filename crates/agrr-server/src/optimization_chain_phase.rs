//! Cultivation-plan optimization phase updates and Cable broadcasts (edge adapter).

use crate::adapters::PassthroughTranslator;
use crate::cable::CableHub;
use crate::state::AppState;
use agrr_adapters_sqlite::CultivationPlanSqliteGateway;
use agrr_domain::cultivation_plan::dtos::{
    AdvanceCultivationPlanPhaseInput, CultivationPlanPhaseName,
};
use agrr_domain::cultivation_plan::gateways::CultivationPlanGateway;
use agrr_domain::cultivation_plan::interactors::AdvanceCultivationPlanPhaseInteractor;
use agrr_domain::shared::ports::CultivationPlanPhaseBroadcastPort;
use rusqlite::params;
use serde_json::{json, Value};
use std::sync::Arc;
use tracing::{error, warn};

struct CablePhaseBroadcast {
    hub: Arc<CableHub>,
}

impl CultivationPlanPhaseBroadcastPort for CablePhaseBroadcast {
    fn broadcast_phase_update(&self, plan_id: i64, _channel_class: &str, payload: &Value) {
        self.hub.broadcast_plan_message(plan_id, payload.clone());
    }
}

pub(crate) fn plan_still_optimizing(pool: &agrr_adapters_sqlite::SqlitePool, plan_id: i64) -> bool {
    pool.with_read(|conn| {
        let status: String = conn.query_row(
            "SELECT status FROM cultivation_plans WHERE id = ?1",
            params![plan_id],
            |row| row.get(0),
        )?;
        Ok(status == "optimizing")
    })
    .unwrap_or(false)
}

/// Runs `step` when the plan is still optimizing. On failure, optionally advances to `failed`.
/// Returns `true` to continue the job chain, `false` to stop remaining steps for this plan.
pub(crate) fn run_guarded_optimization_step(
    state: &AppState,
    plan_id: i64,
    channel: &str,
    step_name: &'static str,
    failure_subphase: Option<&str>,
    step: impl FnOnce() -> Result<(), String>,
) -> bool {
    let pool = state.sqlite.clone();
    if !plan_still_optimizing(&pool, plan_id) {
        return false;
    }
    match step() {
        Ok(()) => true,
        Err(e) => {
            warn!(
                plan_id,
                step = step_name,
                error = %e,
                "optimization chain step failed"
            );
            if let Some(subphase) = failure_subphase {
                if let Err(phase_err) = advance_phase(
                    state,
                    plan_id,
                    channel,
                    CultivationPlanPhaseName::PhaseFailed,
                    Some(subphase),
                ) {
                    error!(
                        plan_id,
                        step = step_name,
                        subphase,
                        error = %phase_err,
                        "optimization chain: failed to persist failed phase after step error"
                    );
                }
            }
            false
        }
    }
}

pub(crate) fn advance_phase(
    state: &AppState,
    plan_id: i64,
    channel: &str,
    phase_name: CultivationPlanPhaseName,
    failure_subphase: Option<&str>,
) -> Result<(), String> {
    let plan_gateway = CultivationPlanSqliteGateway::new(state.sqlite.clone());
    let translator = PassthroughTranslator;
    let broadcast = CablePhaseBroadcast {
        hub: state.cable_hub.clone(),
    };
    let interactor =
        AdvanceCultivationPlanPhaseInteractor::new(&plan_gateway, &translator, &broadcast);
    interactor
        .call(AdvanceCultivationPlanPhaseInput {
            plan_id,
            phase_name,
            channel_class: Some(channel.to_string()),
            failure_subphase: failure_subphase.map(str::to_string),
        })
        .map_err(|e| e.to_string())?;
    Ok(())
}

pub(crate) fn broadcast_completed(
    hub: &CableHub,
    plan_id: i64,
    pool: &agrr_adapters_sqlite::SqlitePool,
) {
    let gateway = CultivationPlanSqliteGateway::new(pool.clone());
    let Ok(plan) = gateway.find_by_id(plan_id) else {
        return;
    };
    let Ok(field_cultivations) = gateway.list_by_plan_id(plan_id) else {
        return;
    };
    let statuses: Vec<String> = field_cultivations
        .iter()
        .filter_map(|fc| fc.status.clone())
        .collect();
    let plan_status = plan.status.as_deref().unwrap_or("");
    let all_fc_completed = !field_cultivations.is_empty()
        && statuses.iter().all(|s| s == "completed");
    if plan_status != "completed" || !all_fc_completed {
        eprintln!(
            "optimization chain: skip broadcast_completed plan_id={plan_id} status={plan_status} field_cultivations={}",
            field_cultivations.len()
        );
        return;
    }
    hub.broadcast_plan_message(
        plan_id,
        json!({
            "status": "completed",
            "progress": 100,
            "phase": "completed",
            "phase_message": "Completed",
            "message_key": "models.cultivation_plan.phases.completed"
        }),
    );
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cable::CableHub;
    use crate::test_support::{
        plan_status, seed_field_cultivation, set_plan_status, test_app_state, test_pool_with_plan,
    };
    use std::sync::atomic::{AtomicBool, Ordering};

    #[test]
    fn advance_phase_returns_err_when_plan_missing() {
        let state = test_app_state(test_pool_with_plan(1).pool);
        let err = advance_phase(
            &state,
            999,
            "PublicPlanChannel",
            CultivationPlanPhaseName::StartOptimizing,
            None,
        )
        .expect_err("missing plan should fail");
        assert!(
            !err.is_empty(),
            "error message should describe failure: {err}"
        );
    }

    #[test]
    fn plan_still_optimizing_reflects_db_status() {
        let db = test_pool_with_plan(1);
        set_plan_status(&db.pool, 1, "optimizing");
        assert!(plan_still_optimizing(&db.pool, 1));

        set_plan_status(&db.pool, 1, "failed");
        assert!(!plan_still_optimizing(&db.pool, 1));
    }

    #[test]
    fn guarded_step_skips_when_plan_not_optimizing() {
        let db = test_pool_with_plan(1);
        let state = test_app_state(db.pool.clone());
        set_plan_status(&db.pool, 1, "failed");
        let step_ran = AtomicBool::new(false);

        let continue_chain = run_guarded_optimization_step(
            &state,
            1,
            "PlansOptimizationChannel",
            "fetch_weather_data",
            Some("fetching_weather"),
            || {
                step_ran.store(true, Ordering::SeqCst);
                Ok(())
            },
        );

        assert!(!continue_chain);
        assert!(!step_ran.load(Ordering::SeqCst));
    }

    #[test]
    fn guarded_step_returns_true_on_success() {
        let db = test_pool_with_plan(1);
        let state = test_app_state(db.pool.clone());
        set_plan_status(&db.pool, 1, "optimizing");

        let continue_chain = run_guarded_optimization_step(
            &state,
            1,
            "PlansOptimizationChannel",
            "fetch_weather_data",
            Some("fetching_weather"),
            || Ok(()),
        );

        assert!(continue_chain);
        assert_eq!(plan_status(&db.pool, 1), "optimizing");
    }

    #[test]
    fn guarded_step_marks_plan_failed_when_step_errors() {
        let db = test_pool_with_plan(1);
        let state = test_app_state(db.pool.clone());
        set_plan_status(&db.pool, 1, "optimizing");

        let continue_chain = run_guarded_optimization_step(
            &state,
            1,
            "PlansOptimizationChannel",
            "fetch_weather_data",
            Some("fetching_weather"),
            || Err("daemon unavailable".into()),
        );

        assert!(!continue_chain);
        assert_eq!(plan_status(&db.pool, 1), "failed");
    }

    #[test]
    fn broadcast_completed_skips_when_field_cultivations_incomplete() {
        let db = test_pool_with_plan(1);
        let hub = CableHub::default();
        set_plan_status(&db.pool, 1, "completed");
        seed_field_cultivation(&db.pool, 1, 1, "optimizing");

        let rt = tokio::runtime::Runtime::new().expect("tokio runtime");
        let mut rx = rt.block_on(hub.subscribe_plan(1));
        broadcast_completed(&hub, 1, &db.pool);

        let received = rt.block_on(async {
            tokio::time::timeout(std::time::Duration::from_millis(100), rx.recv()).await
        });
        assert!(
            received.is_err(),
            "incomplete field cultivations must not trigger completed broadcast"
        );
    }

    #[test]
    fn broadcast_completed_emits_when_plan_and_fields_are_completed() {
        let db = test_pool_with_plan(1);
        let hub = CableHub::default();
        set_plan_status(&db.pool, 1, "completed");
        seed_field_cultivation(&db.pool, 1, 1, "completed");

        let rt = tokio::runtime::Runtime::new().expect("tokio runtime");
        let mut rx = rt.block_on(hub.subscribe_plan(1));
        broadcast_completed(&hub, 1, &db.pool);

        let payload = rt
            .block_on(async {
                tokio::time::timeout(std::time::Duration::from_secs(1), rx.recv())
                    .await
                    .expect("timeout waiting for broadcast")
                    .expect("broadcast channel closed")
            });
        let value: Value = serde_json::from_str(&payload).expect("json payload");
        assert_eq!(value.get("status").and_then(|v| v.as_str()), Some("completed"));
        assert_eq!(value.get("phase").and_then(|v| v.as_str()), Some("completed"));
    }
}
