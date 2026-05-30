//! Run the in-process optimization job chain for one plan (local E2E).
//!
//!   AGRR_SQLITE_PATH=storage/development.sqlite3 \
//!     cargo run -q -p agrr-server --bin optimization-chain-run -- --plan-id 14
//!
//! Requires agrr daemon for predict/allocate when DB lacks predicted weather.

use std::env;
use std::process::ExitCode;
use std::time::Duration;

use agrr_adapters_sqlite::SqlitePool;
use agrr_domain::weather_data::OptimizationJobChainWeatherComputation;
use agrr_server::adapters::SystemClock;
use agrr_server::optimization_chain_run::{
    load_chain_context, run_fetch_weather_step, run_optimization_step, run_weather_prediction_step,
};
use agrr_server::optimization_job_chain::enqueue_private_plan_optimization_chain;
use agrr_server::state::AppState;
use rusqlite::params;

fn plan_id_from_args() -> i64 {
    let args: Vec<String> = env::args().collect();
    for i in 0..args.len().saturating_sub(1) {
        if args[i] == "--plan-id" {
            if let Ok(id) = args[i + 1].parse() {
                return id;
            }
        }
    }
    env::var("SPIKE_PLAN_ID")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(14)
}

fn step_from_args() -> Option<String> {
    let args: Vec<String> = env::args().collect();
    for i in 0..args.len().saturating_sub(1) {
        if args[i] == "--step" {
            return Some(args[i + 1].clone());
        }
    }
    None
}

fn channel_from_args() -> String {
    let args: Vec<String> = env::args().collect();
    for i in 0..args.len().saturating_sub(1) {
        if args[i] == "--channel" {
            return args[i + 1].clone();
        }
    }
    env::var("OPTIMIZATION_CHANNEL").unwrap_or_else(|_| "OptimizationChannel".into())
}

fn read_plan_status(pool: &SqlitePool, plan_id: i64) -> Option<(String, Option<String>)> {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT status, optimization_phase FROM cultivation_plans WHERE id = ?1",
            params![plan_id],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )
    })
    .ok()
}

fn main() -> ExitCode {
    let plan_id = plan_id_from_args();
    let channel = channel_from_args();
    let sqlite_path = env::var("AGRR_SQLITE_PATH").unwrap_or_else(|_| {
        "storage/development.sqlite3".to_string()
    });

    println!("optimization-chain-run");
    println!("  AGRR_SQLITE_PATH={sqlite_path}");
    println!("  plan_id={plan_id} channel={channel}");

    let state = AppState::from_env();
    let pool = state.sqlite.clone();

    if read_plan_status(&pool, plan_id).is_none() {
        eprintln!("plan {plan_id} not found");
        return ExitCode::from(2);
    }

    if let Some(step) = step_from_args() {
        let Some(ctx) = load_chain_context(&pool, plan_id) else {
            eprintln!("chain context not found for plan {plan_id}");
            return ExitCode::from(2);
        };
        let clock = SystemClock;
        let window =
            OptimizationJobChainWeatherComputation::weather_window(ctx.latest_weather_date, &clock);
        let result = match step.as_str() {
            "fetch" => run_fetch_weather_step(
                &state,
                plan_id,
                &channel,
                &ctx,
                window.start_date,
                window.end_date,
            ),
            "predict" => {
                run_weather_prediction_step(&state, plan_id, &channel, window.end_date)
            }
            "optimize" => run_optimization_step(&state, plan_id, &channel),
            other => {
                eprintln!("unknown --step {other} (fetch|predict|optimize)");
                return ExitCode::from(2);
            }
        };
        match result {
            Ok(()) => {
                println!("step {step} ok");
                return ExitCode::SUCCESS;
            }
            Err(e) => {
                eprintln!("step {step} failed: {e}");
                return ExitCode::from(1);
            }
        }
    }

    enqueue_private_plan_optimization_chain(plan_id, &channel, &state);

    let timeout = env::var("CHAIN_RUN_TIMEOUT_SEC")
        .ok()
        .and_then(|s| s.parse().ok())
        .unwrap_or(600);
    let poll = Duration::from_secs(2);

    let rt = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("tokio runtime");
    rt.block_on(async {
    for elapsed in (0..timeout).step_by(poll.as_secs() as usize) {
        tokio::time::sleep(poll).await;
        let Some((status, phase)) = read_plan_status(&pool, plan_id) else {
            eprintln!("plan disappeared");
            return ExitCode::from(2);
        };
        let fc_count: i64 = pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT COUNT(*) FROM field_cultivations WHERE cultivation_plan_id = ?1",
                    params![plan_id],
                    |row| row.get(0),
                )
            })
            .unwrap_or(0);
        println!(
            "  [{elapsed}s] status={status} phase={:?} field_cultivations={fc_count}",
            phase
        );
        if status == "completed" {
            if fc_count > 0 {
                println!("chain finished: completed");
                return ExitCode::SUCCESS;
            }
            eprintln!("chain finished: status=completed but field_cultivations=0 (invalid success)");
            return ExitCode::from(1);
        }
        if status == "failed" {
            eprintln!("chain finished: failed (phase={phase:?})");
            return ExitCode::from(1);
        }
    }

    eprintln!("timed out after {timeout}s");
    ExitCode::from(1)
    })
}
