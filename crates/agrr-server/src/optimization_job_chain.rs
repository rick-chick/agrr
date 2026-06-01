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
    true
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::test_app_state;
    use agrr_adapters_sqlite::SqlitePool;
    use tempfile::NamedTempFile;

    struct ChainTestDb {
        pool: SqlitePool,
        _file: NamedTempFile,
    }

    fn test_pool_for_chain_enqueue(plan_id: i64) -> ChainTestDb {
        let file = NamedTempFile::new().expect("temp db");
        let path = file.path().to_str().expect("utf8 path");
        let pool = SqlitePool::new(path);
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE farms (
                   id INTEGER PRIMARY KEY,
                   name TEXT,
                   latitude REAL NOT NULL,
                   longitude REAL NOT NULL,
                   weather_location_id INTEGER
                 );
                 CREATE TABLE cultivation_plans (
                   id INTEGER PRIMARY KEY,
                   farm_id INTEGER,
                   user_id INTEGER,
                   total_area REAL,
                   plan_type TEXT,
                   plan_year INTEGER,
                   plan_name TEXT,
                   planning_start_date TEXT,
                   planning_end_date TEXT,
                   status TEXT,
                   session_id TEXT,
                   optimization_phase TEXT,
                   optimization_phase_message TEXT,
                   created_at TEXT DEFAULT (datetime('now')),
                   updated_at TEXT DEFAULT (datetime('now'))
                 );
                 CREATE TABLE cultivation_plan_crops (
                   id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER
                 );
                 CREATE TABLE cultivation_plan_fields (
                   id INTEGER PRIMARY KEY, cultivation_plan_id INTEGER
                 );
                 CREATE TABLE field_cultivations (
                   id INTEGER PRIMARY KEY,
                   cultivation_plan_id INTEGER,
                   cultivation_plan_field_id INTEGER,
                   cultivation_plan_crop_id INTEGER,
                   area REAL,
                   status TEXT
                 );",
            )?;
            conn.execute(
                "INSERT INTO farms (id, name, latitude, longitude) VALUES (1, 'Test Farm', 35.0, 139.0)",
                [],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plans (id, farm_id, user_id, plan_type, status, total_area)
                 VALUES (?1, 1, 1, 'public', 'pending', 100.0)",
                rusqlite::params![plan_id],
            )?;
            Ok(())
        })
        .expect("seed");
        ChainTestDb { pool, _file: file }
    }

    /// Omits `optimization_phase` so `StartOptimizing` cannot persist (advance_phase fails).
    fn test_pool_start_optimizing_update_fails(plan_id: i64) -> ChainTestDb {
        let file = NamedTempFile::new().expect("temp db");
        let path = file.path().to_str().expect("utf8 path");
        let pool = SqlitePool::new(path);
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE farms (
                   id INTEGER PRIMARY KEY,
                   name TEXT,
                   latitude REAL NOT NULL,
                   longitude REAL NOT NULL,
                   weather_location_id INTEGER
                 );
                 CREATE TABLE cultivation_plans (
                   id INTEGER PRIMARY KEY,
                   farm_id INTEGER,
                   user_id INTEGER,
                   total_area REAL,
                   plan_type TEXT,
                   status TEXT
                 );",
            )?;
            conn.execute(
                "INSERT INTO farms (id, name, latitude, longitude) VALUES (1, 'Test Farm', 35.0, 139.0)",
                [],
            )?;
            conn.execute(
                "INSERT INTO cultivation_plans (id, farm_id, user_id, plan_type, status, total_area)
                 VALUES (?1, 1, 1, 'public', 'pending', 100.0)",
                rusqlite::params![plan_id],
            )?;
            Ok(())
        })
        .expect("seed");
        ChainTestDb { pool, _file: file }
    }

    #[test]
    fn returns_false_when_start_optimizing_fails() {
        let db = test_pool_start_optimizing_update_fails(1);
        let state = test_app_state(db.pool);

        assert!(!enqueue_private_plan_optimization_chain(
            1,
            "PlansOptimizationChannel",
            &state
        ));
    }

    #[test]
    fn returns_true_when_start_optimizing_succeeds() {
        let db = test_pool_for_chain_enqueue(1);
        let state = test_app_state(db.pool);

        assert!(enqueue_private_plan_optimization_chain(
            1,
            "PlansOptimizationChannel",
            &state
        ));
    }
}
