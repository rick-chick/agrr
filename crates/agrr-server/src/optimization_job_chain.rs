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

use crate::adapters::SystemClock;
use crate::jobs::JobStep;
use crate::optimization_chain_phase::{advance_phase, run_guarded_optimization_step};
use crate::optimization_chain_run::{
    load_chain_context, run_fetch_weather_step, run_optimization_step, run_plan_finalize_step,
    run_weather_prediction_step,
};
use crate::state::AppState;
use agrr_domain::cultivation_plan::dtos::CultivationPlanPhaseName;
use agrr_domain::weather_data::OptimizationJobChainWeatherComputation;
use std::sync::Arc;
use tracing::{error, info};

/// Enqueue weather → prediction → optimization → finalize.
///
/// No `TaskScheduleGenerationJob` and no `phase_optimization_completed` / `task_schedule_generating`
/// broadcasts (Rails-only intermediates before `completed`).
/// Returns `true` when the chain was enqueued; `false` when context is missing or
/// `StartOptimizing` could not be applied (no steps are scheduled).
pub fn enqueue_private_plan_optimization_chain(plan_id: i64, channel: &str, state: &AppState) -> bool {
    let channel = channel.to_string();
    let hub = state.cable_hub.clone();
    let pool = state.sqlite.clone();
    let dispatcher = state.optimization_chain_dispatcher.clone();
    let state_clone = state.clone();

    let ctx = match load_chain_context(&pool, plan_id) {
        Ok(Some(ctx)) => ctx,
        Ok(None) => {
            error!(plan_id, "optimization chain: plan context not found");
            return false;
        }
        Err(e) => {
            error!(plan_id, error = %e, "optimization chain: weather storage unavailable");
            return false;
        }
    };

    let clock = SystemClock;
    let weather_window = OptimizationJobChainWeatherComputation::weather_window(
        ctx.latest_weather_date,
        &clock,
    );

    if let Err(e) = advance_phase(
        &state_clone,
        plan_id,
        &channel,
        CultivationPlanPhaseName::StartOptimizing,
        None,
    ) {
        error!(
            plan_id,
            error = %e,
            "optimization chain: start_optimizing failed; chain not enqueued"
        );
        return false;
    }

    let mut steps: Vec<JobStep> = vec![];

    {
        let state = state_clone.clone();
        let channel = channel.clone();
        let start = weather_window.start_date;
        let end = weather_window.end_date;
        let ctx = ctx.clone();
        steps.push(JobStep {
            name: "fetch_weather_data",
            run: Arc::new(move || {
                let state = state.clone();
                let channel = channel.clone();
                let ctx = ctx.clone();
                Box::pin(async move {
                    run_guarded_optimization_step(
                        &state,
                        plan_id,
                        &channel,
                        "fetch_weather_data",
                        Some("fetching_weather"),
                        || run_fetch_weather_step(&state, plan_id, &channel, &ctx, start, end),
                    )
                })
            }),
        });
    }

    {
        let state = state_clone.clone();
        let channel = channel.clone();
        let end = weather_window.end_date;
        steps.push(JobStep {
            name: "weather_prediction",
            run: Arc::new(move || {
                let state = state.clone();
                let channel = channel.clone();
                Box::pin(async move {
                    run_guarded_optimization_step(
                        &state,
                        plan_id,
                        &channel,
                        "weather_prediction",
                        Some("predicting_weather"),
                        || run_weather_prediction_step(&state, plan_id, &channel, end),
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::{test_app_state, test_pool_with_plan, test_pool_without_optimization_phase_column};

    #[test]
    fn returns_false_when_start_optimizing_fails() {
        let db = test_pool_without_optimization_phase_column(1);
        let state = test_app_state(db.pool);

        assert!(!enqueue_private_plan_optimization_chain(
            1,
            "PlansOptimizationChannel",
            &state
        ));
    }

    #[test]
    fn returns_true_when_start_optimizing_succeeds() {
        let db = test_pool_with_plan(1);
        let state = test_app_state(db.pool);

        assert!(enqueue_private_plan_optimization_chain(
            1,
            "PlansOptimizationChannel",
            &state
        ));
    }

    #[test]
    fn returns_false_when_plan_context_missing() {
        let db = test_pool_with_plan(1);
        let state = test_app_state(db.pool);

        assert!(!enqueue_private_plan_optimization_chain(
            999,
            "PlansOptimizationChannel",
            &state
        ));
    }
}
