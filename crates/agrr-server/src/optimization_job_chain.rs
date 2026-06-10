//! Private/public plan optimization job chains (in-process) + Cable progress broadcast.
//!
//! Ruby: `PrivatePlanOptimizationJobChainBuilder` + job classes.
//!
//! Chains run on [`AppState::optimization_chain_dispatcher`], separate from
//! [`AppState::weather_fetch_job_dispatcher`] (farm / scheduler weather jobs), so long
//! farm/scheduler weather fetches cannot stall plan optimization. Different plans on the
//! optimization dispatcher run **concurrently** (steps within one plan stay sequential).
//!
//! Step bodies and phase guards live in [`crate::optimization_chain_run`] and
//! [`crate::optimization_chain_phase`].

use crate::jobs::JobStep;
use crate::optimization_chain_phase::run_guarded_optimization_step;
use crate::optimization_chain_run::{
    new_bootstrap_slot, plan_exists_in_db, run_bootstrap_step, run_fetch_weather_step,
    run_optimization_step, run_plan_finalize_step, run_weather_prediction_step, BootstrapData,
};
use crate::state::AppState;
use std::sync::Arc;
use tracing::{error, info};

/// Schedule bootstrap → weather → prediction → optimization → finalize.
///
/// HTTP handlers return after this call; GCS `load_chain_context` and `StartOptimizing` run
/// inside the async `bootstrap` step.
///
/// Returns `true` when the chain was enqueued; `false` when the plan row is missing.
pub fn enqueue_private_plan_optimization_chain(plan_id: i64, channel: &str, state: &AppState) -> bool {
    let channel = channel.to_string();
    let hub = state.cable_hub.clone();
    let pool = state.sqlite.clone();
    let dispatcher = state.optimization_chain_dispatcher.clone();
    let state_clone = state.clone();

    if !plan_exists_in_db(&pool, plan_id) {
        error!(plan_id, "optimization chain: plan not found");
        return false;
    }

    let bootstrap_slot = new_bootstrap_slot();
    let mut steps: Vec<JobStep> = vec![];

    {
        let state = state_clone.clone();
        let channel = channel.clone();
        let slot = bootstrap_slot.clone();
        steps.push(JobStep {
            name: "bootstrap",
            run: Arc::new(move || {
                let state = state.clone();
                let channel = channel.clone();
                let slot = slot.clone();
                Box::pin(async move { run_bootstrap_step(&state, plan_id, &channel, &slot).await })
            }),
        });
    }

    {
        let state = state_clone.clone();
        let channel = channel.clone();
        let slot = bootstrap_slot.clone();
        steps.push(JobStep {
            name: "fetch_weather_data",
            run: Arc::new(move || {
                let state = state.clone();
                let channel = channel.clone();
                let slot = slot.clone();
                Box::pin(async move {
                    let Some(BootstrapData {
                        ctx,
                        start_date,
                        end_date,
                    }) = bootstrap_data(&slot)
                    else {
                        return false;
                    };
                    run_guarded_optimization_step(
                        &state,
                        plan_id,
                        &channel,
                        "fetch_weather_data",
                        Some("fetching_weather"),
                        || run_fetch_weather_step(&state, plan_id, &channel, &ctx, start_date, end_date),
                    )
                })
            }),
        });
    }

    {
        let state = state_clone.clone();
        let channel = channel.clone();
        let slot = bootstrap_slot.clone();
        steps.push(JobStep {
            name: "weather_prediction",
            run: Arc::new(move || {
                let state = state.clone();
                let channel = channel.clone();
                let slot = slot.clone();
                Box::pin(async move {
                    let Some(BootstrapData { end_date, .. }) = bootstrap_data(&slot) else {
                        return false;
                    };
                    run_guarded_optimization_step(
                        &state,
                        plan_id,
                        &channel,
                        "weather_prediction",
                        Some("predicting_weather"),
                        || run_weather_prediction_step(&state, plan_id, &channel, end_date),
                    )
                })
            }),
        });
    }

    {
        let state = state_clone.clone();
        let channel = channel.clone();
        steps.push(JobStep {
            name: "optimization",
            run: Arc::new(move || {
                let state = state.clone();
                let channel = channel.clone();
                Box::pin(async move {
                    run_guarded_optimization_step(
                        &state,
                        plan_id,
                        &channel,
                        "optimization",
                        Some("optimizing"),
                        || run_optimization_step(&state, plan_id, &channel),
                    )
                })
            }),
        });
    }

    {
        let hub = hub.clone();
        let channel = channel.clone();
        let state = state_clone.clone();
        steps.push(JobStep {
            name: "plan_finalize",
            run: Arc::new(move || {
                let hub = hub.clone();
                let channel = channel.clone();
                let state = state.clone();
                Box::pin(async move {
                    let ok = run_guarded_optimization_step(
                        &state,
                        plan_id,
                        &channel,
                        "plan_finalize",
                        None,
                        || run_plan_finalize_step(&state, plan_id, &channel, &hub),
                    );
                    if ok {
                        info!(plan_id, "optimization chain finalized");
                    }
                    ok
                })
            }),
        });
    }

    info!(plan_id, steps = steps.len(), "optimization chain enqueued");
    dispatcher.enqueue_chain(steps);
    true
}

fn bootstrap_data(slot: &crate::optimization_chain_run::BootstrapSlot) -> Option<BootstrapData> {
    slot.get()?.as_ref().ok().cloned()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::{test_app_state, test_pool_with_plan, test_pool_without_optimization_phase_column};
    use std::thread;
    use std::time::{Duration, Instant};

    fn wait_until(timeout: Duration, mut condition: impl FnMut() -> bool) -> bool {
        let deadline = Instant::now() + timeout;
        while Instant::now() < deadline {
            if condition() {
                return true;
            }
            thread::sleep(Duration::from_millis(10));
        }
        false
    }

    fn plan_status(pool: &agrr_adapters_sqlite::SqlitePool, plan_id: i64) -> String {
        pool.with_read(|conn| {
            conn.query_row(
                "SELECT status FROM cultivation_plans WHERE id = ?1",
                rusqlite::params![plan_id],
                |row| row.get(0),
            )
        })
        .expect("status")
    }

    #[test]
    fn returns_false_when_plan_missing() {
        let db = test_pool_with_plan(1);
        let state = test_app_state(db.pool);

        assert!(!enqueue_private_plan_optimization_chain(
            999,
            "PlansOptimizationChannel",
            &state
        ));
    }

    #[test]
    fn returns_true_and_leaves_plan_pending_before_bootstrap_runs() {
        let db = test_pool_with_plan(1);
        let pool = db.pool.clone();
        let state = test_app_state(db.pool);

        assert!(enqueue_private_plan_optimization_chain(
            1,
            "PlansOptimizationChannel",
            &state
        ));
        assert_eq!(plan_status(&pool, 1), "pending");
    }

    #[test]
    fn schedules_chain_even_when_bootstrap_will_fail() {
        let db = test_pool_without_optimization_phase_column(1);
        let pool = db.pool.clone();
        let state = test_app_state(db.pool);

        assert!(enqueue_private_plan_optimization_chain(
            1,
            "PlansOptimizationChannel",
            &state
        ));

        assert!(
            wait_until(Duration::from_secs(2), || plan_status(&pool, 1) != "optimizing"),
            "bootstrap must not reach optimizing without phase columns"
        );
        assert_eq!(
            plan_status(&pool, 1),
            "pending",
            "phase persistence is unavailable; plan stays pending after bootstrap error"
        );
    }

    #[test]
    fn returns_true_when_plan_exists() {
        let db = test_pool_with_plan(1);
        let state = test_app_state(db.pool);

        assert!(enqueue_private_plan_optimization_chain(
            1,
            "PlansOptimizationChannel",
            &state
        ));
    }
}
