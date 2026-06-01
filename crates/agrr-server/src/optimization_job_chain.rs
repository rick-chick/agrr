//! Private/public plan optimization job chains (in-process) + Cable progress broadcast.
//!
//! Ruby: `PrivatePlanOptimizationJobChainBuilder` + job classes.
//!
//! Chains run on [`AppState::optimization_chain_dispatcher`], separate from
//! [`AppState::weather_fetch_job_dispatcher`] (farm / scheduler weather jobs), so long
//! weather fetches cannot stall plan optimization.

use crate::adapters::SystemClock;
use crate::jobs::JobStep;
use crate::optimization_chain_phase::{advance_phase, plan_still_optimizing};
use crate::optimization_chain_run::{
    load_chain_context, run_fetch_weather_step, run_optimization_step, run_plan_finalize_step,
    run_weather_prediction_step,
};
use crate::state::AppState;
use agrr_domain::cultivation_plan::dtos::CultivationPlanPhaseName;
use agrr_domain::weather_data::OptimizationJobChainWeatherComputation;
use std::sync::Arc;
use tracing::{error, info, warn};

/// Enqueue weather → prediction → optimization → finalize.
///
/// No `TaskScheduleGenerationJob` and no `phase_optimization_completed` / `task_schedule_generating`
/// broadcasts (Rails-only intermediates before `completed`).
pub fn enqueue_private_plan_optimization_chain(plan_id: i64, channel: &str, state: &AppState) {
    let channel = channel.to_string();
    let hub = state.cable_hub.clone();
    let pool = state.sqlite.clone();
    let dispatcher = state.optimization_chain_dispatcher.clone();
    let state_clone = state.clone();

    let ctx = match load_chain_context(&pool, plan_id) {
        Ok(Some(ctx)) => ctx,
        Ok(None) => {
            error!(plan_id, "optimization chain: plan context not found");
            return;
        }
        Err(e) => {
            error!(plan_id, error = %e, "optimization chain: weather storage unavailable");
            return;
        }
    };

    let clock = SystemClock;
    let weather_window = OptimizationJobChainWeatherComputation::weather_window(
        ctx.latest_weather_date,
        &clock,
    );

    let _ = advance_phase(
        &state_clone,
        plan_id,
        &channel,
        CultivationPlanPhaseName::StartOptimizing,
        None,
    );

    let mut steps: Vec<JobStep> = vec![];

    {
        let state = state_clone.clone();
        let channel = channel.clone();
        let pool = pool.clone();
        let start = weather_window.start_date;
        let end = weather_window.end_date;
        let ctx = ctx.clone();
        steps.push(JobStep {
            name: "fetch_weather_data",
            run: Arc::new(move || {
                let state = state.clone();
                let channel = channel.clone();
                let pool = pool.clone();
                let ctx = ctx.clone();
                Box::pin(async move {
                    if !plan_still_optimizing(&pool, plan_id) {
                        return false;
                    }
                    match run_fetch_weather_step(&state, plan_id, &channel, &ctx, start, end) {
                        Ok(()) => true,
                        Err(e) => {
                            eprintln!("fetch_weather_data failed plan_id={plan_id}: {e}");
                            warn!(plan_id, error = %e, "fetch_weather_data failed");
                            let _ = advance_phase(
                                &state,
                                plan_id,
                                &channel,
                                CultivationPlanPhaseName::PhaseFailed,
                                Some("fetching_weather"),
                            );
                            false
                        }
                    }
                })
            }),
        });
    }

    {
        let state = state_clone.clone();
        let channel = channel.clone();
        let pool = pool.clone();
        let end = weather_window.end_date;
        steps.push(JobStep {
            name: "weather_prediction",
            run: Arc::new(move || {
                let state = state.clone();
                let channel = channel.clone();
                let pool = pool.clone();
                Box::pin(async move {
                    if !plan_still_optimizing(&pool, plan_id) {
                        return false;
                    }
                    match run_weather_prediction_step(&state, plan_id, &channel, end) {
                        Ok(()) => true,
                        Err(e) => {
                            eprintln!("weather_prediction failed plan_id={plan_id}: {e}");
                            eprintln!(
                                "  hint: ensure agrr daemon ({}) or set AGRR_USE_MOCK=true for local dev",
                                std::env::var("AGRR_SOCKET_PATH")
                                    .unwrap_or_else(|_| "/tmp/agrr.sock".into())
                            );
                            warn!(plan_id, error = %e, "weather_prediction failed");
                            let _ = advance_phase(
                                &state,
                                plan_id,
                                &channel,
                                CultivationPlanPhaseName::PhaseFailed,
                                Some("predicting_weather"),
                            );
                            false
                        }
                    }
                })
            }),
        });
    }

    {
        let state = state_clone.clone();
        let channel = channel.clone();
        let pool = pool.clone();
        steps.push(JobStep {
            name: "optimization",
            run: Arc::new(move || {
                let state = state.clone();
                let channel = channel.clone();
                let pool = pool.clone();
                Box::pin(async move {
                    if !plan_still_optimizing(&pool, plan_id) {
                        return false;
                    }
                    match run_optimization_step(&state, plan_id, &channel) {
                        Ok(()) => true,
                        Err(e) => {
                            eprintln!("optimization failed plan_id={plan_id}: {e}");
                            warn!(plan_id, error = %e, "optimization failed");
                            let _ = advance_phase(
                                &state,
                                plan_id,
                                &channel,
                                CultivationPlanPhaseName::PhaseFailed,
                                Some("optimizing"),
                            );
                            false
                        }
                    }
                })
            }),
        });
    }

    {
        let hub = hub.clone();
        let pool = pool.clone();
        let channel = channel.clone();
        let state = state_clone.clone();
        steps.push(JobStep {
            name: "plan_finalize",
            run: Arc::new(move || {
                let hub = hub.clone();
                let pool = pool.clone();
                let channel = channel.clone();
                let state = state.clone();
                Box::pin(async move {
                    if !plan_still_optimizing(&pool, plan_id) {
                        return false;
                    }
                    match run_plan_finalize_step(&state, plan_id, &channel, &hub) {
                        Ok(()) => {
                            info!(plan_id, "optimization chain finalized");
                            true
                        }
                        Err(e) => {
                            eprintln!("plan_finalize failed plan_id={plan_id}: {e}");
                            warn!(plan_id, error = %e, "plan_finalize failed");
                            false
                        }
                    }
                })
            }),
        });
    }

    eprintln!("optimization chain enqueued plan_id={plan_id} steps={}", steps.len());
    dispatcher.enqueue_chain(steps);
}
