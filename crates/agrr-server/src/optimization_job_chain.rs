//! Private/public plan optimization job chains (in-process) + Cable progress broadcast.
//!
//! Ruby: `PrivatePlanOptimizationJobChainBuilder` + job classes.

use crate::adapters::{PassthroughTranslator, SystemClock};
use crate::cable::CableHub;
use crate::jobs::JobStep;
use crate::optimization_chain_run::{
    load_chain_context, run_fetch_weather_step, run_optimization_step, run_plan_finalize_step,
    run_weather_prediction_step,
};
use crate::state::AppState;
use agrr_adapters_sqlite::CultivationPlanSqliteGateway;
use agrr_domain::cultivation_plan::dtos::{
    AdvanceCultivationPlanPhaseInput, CultivationPlanPhaseName,
};
use agrr_domain::cultivation_plan::gateways::CultivationPlanGateway;
use agrr_domain::cultivation_plan::interactors::AdvanceCultivationPlanPhaseInteractor;
use agrr_domain::shared::ports::CultivationPlanPhaseBroadcastPort;
use agrr_domain::weather_data::OptimizationJobChainWeatherComputation;
use rusqlite::params;
use serde_json::{json, Value};
use std::sync::Arc;
use tracing::{error, info, warn};

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

pub(crate) fn advance_phase(
    state: &AppState,
    plan_id: i64,
    channel: &str,
    phase_name: CultivationPlanPhaseName,
    failure_subphase: Option<&str>,
) {
    let plan_gateway = CultivationPlanSqliteGateway::new(state.sqlite.clone());
    let translator = PassthroughTranslator;
    let broadcast = CablePhaseBroadcast {
        hub: state.cable_hub.clone(),
    };
    let interactor =
        AdvanceCultivationPlanPhaseInteractor::new(&plan_gateway, &translator, &broadcast);
    let _ = interactor.call(AdvanceCultivationPlanPhaseInput {
        plan_id,
        phase_name,
        channel_class: Some(channel.to_string()),
        failure_subphase: failure_subphase.map(str::to_string),
    });
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

/// Enqueue weather → prediction → optimization → finalize.
///
/// No `TaskScheduleGenerationJob` and no `phase_optimization_completed` / `task_schedule_generating`
/// broadcasts (Rails-only intermediates before `completed`).
pub fn enqueue_private_plan_optimization_chain(plan_id: i64, channel: &str, state: &AppState) {
    let channel = channel.to_string();
    let hub = state.cable_hub.clone();
    let pool = state.sqlite.clone();
    let dispatcher = state.job_dispatcher.clone();
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

    let mut steps: Vec<JobStep> = vec![];

    {
        let state = state_clone.clone();
        let channel = channel.clone();
        steps.push(JobStep {
            name: "start_optimizing",
            run: Arc::new(move || {
                let state = state.clone();
                let channel = channel.clone();
                Box::pin(async move {
                    advance_phase(
                        &state,
                        plan_id,
                        &channel,
                        CultivationPlanPhaseName::StartOptimizing,
                        None,
                    );
                    true
                })
            }),
        });
    }

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
                            advance_phase(
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
                            warn!(plan_id, error = %e, "weather_prediction failed");
                            advance_phase(
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
                            advance_phase(
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

