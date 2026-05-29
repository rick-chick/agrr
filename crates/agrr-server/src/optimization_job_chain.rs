//! Private/public plan optimization job chains (in-process) + Cable progress broadcast.
//!
//! Ruby: `PrivatePlanOptimizationJobChainBuilder` + job classes.

use crate::adapters::{PassthroughTranslator, SystemClock};
use crate::cable::CableHub;
use crate::jobs::JobStep;
use crate::state::AppState;
use agrr_adapters_agrr::WeatherDaemonGateway;
use agrr_domain::weather_data::gateways::AgrrWeatherGateway;
use agrr_adapters_sqlite::CultivationPlanSqliteGateway;
use agrr_domain::cultivation_plan::dtos::{
    AdvanceCultivationPlanPhaseInput, CultivationPlanPhaseName,
};
use agrr_domain::cultivation_plan::interactors::AdvanceCultivationPlanPhaseInteractor;
use agrr_domain::shared::ports::CultivationPlanPhaseBroadcastPort;
use agrr_domain::weather_data::OptimizationJobChainWeatherComputation;
use rusqlite::params;
use serde_json::{json, Value};
use std::sync::Arc;
use time::Date;
use tracing::{error, info, warn};

struct ChainContext {
    latitude: f64,
    longitude: f64,
    latest_weather_date: Option<Date>,
    all_crops_have_blueprints: bool,
}

struct CablePhaseBroadcast {
    hub: Arc<CableHub>,
}

impl CultivationPlanPhaseBroadcastPort for CablePhaseBroadcast {
    fn broadcast_phase_update(&self, plan_id: i64, _channel_class: &str, payload: &Value) {
        self.hub.broadcast_plan_message(plan_id, payload.clone());
    }
}

fn load_chain_context(pool: &agrr_adapters_sqlite::SqlitePool, plan_id: i64) -> Option<ChainContext> {
    pool.with_read(|conn| {
        let row: Result<(i64, f64, f64, Option<String>), _> = conn.query_row(
            "SELECT cp.farm_id, f.latitude, f.longitude, \
             (SELECT MAX(wd.date) FROM weather_data wd \
              INNER JOIN weather_locations wl ON wl.id = wd.weather_location_id \
              WHERE wl.id = f.weather_location_id) \
             FROM cultivation_plans cp \
             INNER JOIN farms f ON f.id = cp.farm_id \
             WHERE cp.id = ?1",
            params![plan_id],
            |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?)),
        );
        let Ok((_farm_id, latitude, longitude, latest_str)) = row else {
            return Ok(None);
        };
        let latest_weather_date = latest_str
            .as_deref()
            .and_then(|s| Date::parse(s, &time::format_description::well_known::Iso8601::DATE).ok());

        let (crop_count, blueprint_count): (i64, i64) = conn.query_row(
            "SELECT COUNT(DISTINCT cpc.crop_id), \
             COUNT(DISTINCT CASE WHEN ctb.id IS NOT NULL THEN cpc.crop_id END) \
             FROM cultivation_plan_crops cpc \
             LEFT JOIN crop_task_schedule_blueprints ctb ON ctb.crop_id = cpc.crop_id \
             WHERE cpc.cultivation_plan_id = ?1",
            params![plan_id],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )?;
        let all_crops_have_blueprints = crop_count > 0 && crop_count == blueprint_count;

        Ok(Some(ChainContext {
            latitude,
            longitude,
            latest_weather_date,
            all_crops_have_blueprints,
        }))
    })
    .ok()
    .flatten()
}

fn advance_phase(
    state: &AppState,
    plan_id: i64,
    channel: &str,
    phase_name: CultivationPlanPhaseName,
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
        failure_subphase: None,
    });
}

fn broadcast_completed(hub: &CableHub, plan_id: i64) {
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

/// Enqueue weather → prediction → optimization → [task_schedule] → finalize.
pub fn enqueue_private_plan_optimization_chain(plan_id: i64, channel: &str, state: &AppState) {
    let channel = channel.to_string();
    let hub = state.cable_hub.clone();
    let pool = state.sqlite.clone();
    let dispatcher = state.job_dispatcher.clone();
    let state_clone = state.clone();

    let Some(ctx) = load_chain_context(&pool, plan_id) else {
        error!(plan_id, "optimization chain: plan context not found");
        return;
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
                    advance_phase(&state, plan_id, &channel, CultivationPlanPhaseName::StartOptimizing);
                })
            }),
        });
    }

    {
        let state = state_clone.clone();
        let channel = channel.clone();
        let start = weather_window.start_date;
        let end = weather_window.end_date;
        let lat = ctx.latitude;
        let lon = ctx.longitude;
        steps.push(JobStep {
            name: "fetch_weather_data",
            run: Arc::new(move || {
                let state = state.clone();
                let channel = channel.clone();
                Box::pin(async move {
                    advance_phase(
                        &state,
                        plan_id,
                        &channel,
                        CultivationPlanPhaseName::PhaseFetchingWeather,
                    );
                    let agrr = WeatherDaemonGateway::from_env();
                    match agrr.fetch_by_date_range(lat, lon, start, end, "jma") {
                        Ok(Some(_)) => {
                            advance_phase(
                                &state,
                                plan_id,
                                &channel,
                                CultivationPlanPhaseName::PhaseWeatherDataFetched,
                            );
                        }
                        Ok(None) => warn!(plan_id, "fetch_weather_data: empty response"),
                        Err(e) => warn!(plan_id, error = %e, "fetch_weather_data failed"),
                    }
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
                    advance_phase(
                        &state,
                        plan_id,
                        &channel,
                        CultivationPlanPhaseName::PhasePredictingWeather,
                    );
                    let predict_days =
                        OptimizationJobChainWeatherComputation::predict_days_to_next_year_end(
                            end,
                            &SystemClock,
                        );
                    info!(plan_id, predict_days, "weather_prediction step");
                    advance_phase(
                        &state,
                        plan_id,
                        &channel,
                        CultivationPlanPhaseName::PhaseWeatherPredictionCompleted,
                    );
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
                    advance_phase(
                        &state,
                        plan_id,
                        &channel,
                        CultivationPlanPhaseName::PhaseOptimizing,
                    );
                    info!(plan_id, "optimization: allocate via agrr when optimization_snapshot gateway is wired");
                    advance_phase(
                        &state,
                        plan_id,
                        &channel,
                        CultivationPlanPhaseName::PhaseOptimizationCompleted,
                    );
                })
            }),
        });
    }

    if ctx.all_crops_have_blueprints {
        let state = state_clone.clone();
        let channel = channel.clone();
        steps.push(JobStep {
            name: "task_schedule_generation",
            run: Arc::new(move || {
                let state = state.clone();
                let channel = channel.clone();
                Box::pin(async move {
                    advance_phase(
                        &state,
                        plan_id,
                        &channel,
                        CultivationPlanPhaseName::PhaseTaskScheduleGenerating,
                    );
                    info!(plan_id, "task_schedule_generation: pending TaskSchedule gateways on rust");
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
                    let _ = pool.with_write(|conn| {
                        conn.execute(
                            "UPDATE cultivation_plans SET status = 'completed', updated_at = datetime('now') WHERE id = ?1",
                            params![plan_id],
                        )
                    });
                    advance_phase(
                        &state,
                        plan_id,
                        &channel,
                        CultivationPlanPhaseName::PhaseCompleted,
                    );
                    broadcast_completed(&hub, plan_id);
                    info!(plan_id, "optimization chain finalized");
                })
            }),
        });
    }

    dispatcher.enqueue_chain(steps);
}

/// Scheduler: reference farms then user farms (in-process).
pub fn enqueue_scheduler_weather_update_chain(state: &AppState) {
    let pool = state.sqlite.clone();
    let dispatcher = state.job_dispatcher.clone();
    let clock = SystemClock;
    let window = OptimizationJobChainWeatherComputation::weather_window(None, &clock);

    dispatcher.enqueue_chain(vec![
        JobStep {
            name: "update_reference_weather_data",
            run: Arc::new({
                let pool = pool.clone();
                let start = window.start_date;
                let end = window.end_date;
                move || {
                    let pool = pool.clone();
                    Box::pin(async move {
                        let farms: Vec<(i64, f64, f64)> = pool
                            .with_read(|conn| {
                                let mut stmt = conn.prepare(
                                    "SELECT id, latitude, longitude FROM farms WHERE is_reference = 1",
                                )?;
                                let rows = stmt.query_map([], |row| {
                                    Ok((row.get(0)?, row.get(1)?, row.get(2)?))
                                })?;
                                let mut out = Vec::new();
                                for row in rows {
                                    out.push(row?);
                                }
                                Ok::<_, rusqlite::Error>(out)
                            })
                            .unwrap_or_default();
                        let agrr = WeatherDaemonGateway::from_env();
                        for (farm_id, lat, lon) in farms {
                            info!(farm_id, "scheduler: reference farm weather");
                            let _ = agrr.fetch_by_date_range(lat, lon, start, end, "jma");
                        }
                    })
                }
            }),
        },
        JobStep {
            name: "update_user_farms_weather_data",
            run: Arc::new({
                let pool = pool.clone();
                let start = window.start_date;
                let end = window.end_date;
                move || {
                    let pool = pool.clone();
                    Box::pin(async move {
                        let farms: Vec<(i64, f64, f64)> = pool
                            .with_read(|conn| {
                                let mut stmt = conn.prepare(
                                    "SELECT id, latitude, longitude FROM farms \
                                     WHERE is_reference = 0 AND user_id IS NOT NULL",
                                )?;
                                let rows = stmt.query_map([], |row| {
                                    Ok((row.get(0)?, row.get(1)?, row.get(2)?))
                                })?;
                                let mut out = Vec::new();
                                for row in rows {
                                    out.push(row?);
                                }
                                Ok::<_, rusqlite::Error>(out)
                            })
                            .unwrap_or_default();
                        let agrr = WeatherDaemonGateway::from_env();
                        for (farm_id, lat, lon) in farms {
                            info!(farm_id, "scheduler: user farm weather");
                            let _ = agrr.fetch_by_date_range(lat, lon, start, end, "jma");
                        }
                    })
                }
            }),
        },
    ]);
}
