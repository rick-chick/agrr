//! Small technical spike: verify Rust can reach Rails-parity optimization prerequisites.
//!
//! Usage:
//!   AGRR_SQLITE_PATH=storage/development.sqlite3 cargo run -q -p agrr-server --bin optimization-chain-spike
//!   AGRR_SQLITE_PATH=... cargo run -q -p agrr-server --bin optimization-chain-spike -- --plan-id 14
//!
//! Requires: agrr daemon socket (`/tmp/agrr.sock` or `AGRR_SOCKET_PATH`).

use std::env;
use std::process::ExitCode;
use std::sync::Arc;

use agrr_adapters_agrr::{AgrrDaemonClient, PlanAllocationAllocateAgrrDaemonGateway, WeatherDaemonGateway};
use agrr_domain::cultivation_plan::gateways::PlanAllocationAllocateGateway;
use agrr_domain::weather_data::gateways::{AgrrWeatherGateway, WeatherDataGateway};
use agrr_adapters_sqlite::{
    CultivationPlanOptimizationSqliteGateway, OptimizationPlanReadSqliteGateway,
    PlanAllocationAdjustReadSqliteGateway, SqlitePool, WeatherDataGatewayBundle,
};
use agrr_domain::cultivation_plan::calculators::OptimizationAllocationInputCalculator;
use agrr_domain::cultivation_plan::dtos::OptimizationPlanSnapshot;
use agrr_domain::weather_data::dtos::CultivationPlanWeather;
use agrr_server::adjust_weather_prediction::existing_prediction_weather_for_allocate;
use agrr_domain::cultivation_plan::gateways::{
    CultivationPlanOptimizationGateway, PlanAllocationAdjustReadGateway,
};
use agrr_domain::cultivation_plan::mappers::load_optimization_plan_read_snapshot;
use agrr_domain::shared::ports::{ClockPort, LoggerPort};
use agrr_domain::weather_data::OptimizationJobChainWeatherComputation;
use serde_json::{json, Value};
use time::{Date, OffsetDateTime};

struct SpikeLogger;

impl LoggerPort for SpikeLogger {
    fn info(&self, message: &str) {
        eprintln!("  [info] {message}");
    }
    fn warn(&self, message: &str) {
        eprintln!("  [warn] {message}");
    }
    fn error(&self, message: &str) {
        eprintln!("  [error] {message}");
    }
    fn debug(&self, _message: &str) {}
}

struct SystemClock;

impl ClockPort for SystemClock {
    fn today(&self) -> Date {
        self.now().date()
    }

    fn now(&self) -> OffsetDateTime {
        OffsetDateTime::now_utc()
    }
}

struct Check {
    name: &'static str,
    ok: bool,
    detail: String,
}

impl Check {
    fn pass(name: &'static str, detail: impl Into<String>) -> Self {
        Self {
            name,
            ok: true,
            detail: detail.into(),
        }
    }

    fn fail(name: &'static str, detail: impl Into<String>) -> Self {
        Self {
            name,
            ok: false,
            detail: detail.into(),
        }
    }
}

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

fn socket_path_display() -> String {
    env::var("AGRR_SOCKET_PATH").unwrap_or_else(|_| "/tmp/agrr.sock".into())
}

fn check_daemon() -> Check {
    let client = AgrrDaemonClient::from_env();
    if client.daemon_running() {
        Check::pass("agrr_daemon", format!("socket {}", socket_path_display()))
    } else {
        Check::fail("agrr_daemon", format!("socket missing: {}", socket_path_display()))
    }
}

fn shared_weather_gateway(pool: &SqlitePool) -> Arc<dyn WeatherDataGateway> {
    Arc::new(
        WeatherDataGatewayBundle::resolve(pool.clone())
            .expect("weather data gateway bundle"),
    )
}

fn check_weather_api(
    lat: f64,
    lon: f64,
    pool: &SqlitePool,
    weather: Arc<dyn WeatherDataGateway>,
    wl_id: Option<i64>,
) -> Check {
    let clock = SystemClock;
    let window = OptimizationJobChainWeatherComputation::weather_window(None, &clock, false);
    // Full history window often yields warnings-only stderr with empty stdout; probe recent days.
    let start = window
        .end_date
        .saturating_sub(time::Duration::days(30));
    let gw = WeatherDaemonGateway::from_env();
    match gw.fetch_by_date_range(lat, lon, start, window.end_date, "jma") {
        Ok(Some(parsed)) => {
            let n = parsed
                .get("data")
                .and_then(|d| d.as_array())
                .map(|a| a.len())
                .unwrap_or(0);
            Check::pass(
                "weather_daemon_gateway",
                format!("{n} days ({}..{}) via WeatherDaemonGateway", start, window.end_date),
            )
        }
        Ok(None) => Check::pass(
            "weather_daemon_gateway",
            "no output file (exit 0); chain skips ingest and uses existing store",
        ),
        Err(e) => {
            let read =
                PlanAllocationAdjustReadSqliteGateway::new(pool.clone(), weather.clone());
            if let Ok(rows) =
                read.list_historical_weather_rows(wl_id, window.start_date, window.end_date)
            {
                let threshold = ((window.end_date - window.start_date).whole_days() + 1) as f64
                    * 0.8;
                if rows.len() as f64 >= threshold {
                    return Check::pass(
                        "weather_daemon_gateway",
                        format!(
                            "daemon fetch failed ({e}); chain uses DB skip ({} rows {}..{})",
                            rows.len(),
                            window.start_date,
                            window.end_date
                        ),
                    );
                }
            }
            Check::fail("weather_daemon_gateway", e.to_string())
        }
    }
}

fn coords_from_snapshot(snapshot: &agrr_domain::cultivation_plan::dtos::PlanAllocationAdjustReadSnapshot) -> Option<(f64, f64, Option<i64>)> {
    let wl = &snapshot.weather_prediction_targets.weather_location;
    let lat = wl.get("latitude").and_then(|v| v.as_f64());
    let lon = wl.get("longitude").and_then(|v| v.as_f64());
    let wl_id = wl.get("id").and_then(|v| v.as_i64());
    if let (Some(lat), Some(lon)) = (lat, lon) {
        return Some((lat, lon, wl_id));
    }
    let farm = &snapshot.weather_prediction_targets.farm;
    let lat = farm.get("latitude").and_then(|v| v.as_f64());
    let lon = farm.get("longitude").and_then(|v| v.as_f64());
    lat.zip(lon).map(|(a, b)| (a, b, wl_id))
}

fn check_sqlite_plan_read(
    pool: &SqlitePool,
    weather: Arc<dyn WeatherDataGateway>,
    plan_id: i64,
) -> (Check, Option<(f64, f64, Option<i64>)>) {
    let gw = PlanAllocationAdjustReadSqliteGateway::new(pool.clone(), weather);
    match gw.find_adjust_read_snapshot_by_plan_id(plan_id) {
        Ok(snapshot) => {
            let fields = snapshot.plan_field_snapshots.len();
            let crops = snapshot.plan_crop_snapshots.len();
            let coords = coords_from_snapshot(&snapshot);
            let detail = format!(
                "plan_id={plan_id} fields={fields} crops={crops} coords={coords:?}"
            );
            (Check::pass("sqlite_plan_adjust_read", detail), coords)
        }
        Err(e) => (Check::fail("sqlite_plan_adjust_read", e.to_string()), None),
    }
}

fn check_sqlite_historical_weather(
    read: &PlanAllocationAdjustReadSqliteGateway,
    wl_id: Option<i64>,
) -> Check {
    let clock = SystemClock;
    let window = OptimizationJobChainWeatherComputation::weather_window(None, &clock, false);
    match read.list_historical_weather_rows(wl_id, window.start_date, window.end_date) {
        Ok(rows) => Check::pass(
            "sqlite_historical_weather",
            format!("{} rows for window {}..{}", rows.len(), window.start_date, window.end_date),
        ),
        Err(e) => Check::fail("sqlite_historical_weather", e.to_string()),
    }
}

fn probe_allocate_daemon_stderr(
    fields: &[Value],
    crops: &[Value],
    weather: &Value,
    planning_start: Date,
    planning_end: Date,
) -> Option<String> {
    let fields_file = tempfile::Builder::new()
        .prefix("spike_fields_")
        .suffix(".json")
        .tempfile()
        .ok()?;
    let crops_file = tempfile::Builder::new()
        .prefix("spike_crops_")
        .suffix(".json")
        .tempfile()
        .ok()?;
    let weather_file = tempfile::Builder::new()
        .prefix("spike_weather_")
        .suffix(".json")
        .tempfile()
        .ok()?;
    let output_file = tempfile::Builder::new()
        .prefix("spike_out_")
        .suffix(".json")
        .tempfile()
        .ok()?;
    let fields_body = json!({ "fields": fields });
    let crops_body = json!({ "crops": crops });
    std::fs::write(fields_file.path(), serde_json::to_string(&fields_body).ok()?).ok()?;
    std::fs::write(crops_file.path(), serde_json::to_string(&crops_body).ok()?).ok()?;
    std::fs::write(weather_file.path(), serde_json::to_string(weather).ok()?).ok()?;

    let args = vec![
        "optimize".into(),
        "allocate".into(),
        "--fields-file".into(),
        fields_file.path().to_string_lossy().into_owned(),
        "--crops-file".into(),
        crops_file.path().to_string_lossy().into_owned(),
        "--weather-file".into(),
        weather_file.path().to_string_lossy().into_owned(),
        "--planning-start".into(),
        planning_start.to_string(),
        "--planning-end".into(),
        planning_end.to_string(),
        "--objective".into(),
        "maximize_profit".into(),
        "--format".into(),
        "json".into(),
        "--max-time".into(),
        "60".into(),
    ];
    let _ = output_file;
    let wrapper = AgrrDaemonClient::from_env().execute_daemon_args(&args).ok()?;
    let exit = wrapper.get("exit_code").and_then(|v| v.as_i64()).unwrap_or(-1);
    let stderr = wrapper
        .get("stderr")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .to_string();
    let _ = std::fs::write("/tmp/agrr-spike-allocate-stderr.txt", &stderr);
    let stderr = stderr.chars().take(300).collect::<String>();
    let stdout_len = wrapper
        .get("stdout")
        .and_then(|v| v.as_str())
        .map(|s| s.len())
        .unwrap_or(0);
    Some(format!("exit_code={exit} stdout_len={stdout_len} stderr={stderr}"))
}

fn allocate_via_daemon_stdout(
    fields: &[Value],
    crops: &[Value],
    weather: &Value,
    planning_start: Date,
    planning_end: Date,
) -> Result<Value, String> {
    let fields_file = tempfile::Builder::new()
        .prefix("spike_fields_")
        .suffix(".json")
        .tempfile()
        .map_err(|e| e.to_string())?;
    let crops_file = tempfile::Builder::new()
        .prefix("spike_crops_")
        .suffix(".json")
        .tempfile()
        .map_err(|e| e.to_string())?;
    let weather_file = tempfile::Builder::new()
        .prefix("spike_weather_")
        .suffix(".json")
        .tempfile()
        .map_err(|e| e.to_string())?;
    std::fs::write(
        fields_file.path(),
        serde_json::to_string(&json!({ "fields": fields })).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    std::fs::write(
        crops_file.path(),
        serde_json::to_string(&json!({ "crops": crops })).map_err(|e| e.to_string())?,
    )
    .map_err(|e| e.to_string())?;
    std::fs::write(weather_file.path(), serde_json::to_string(weather).map_err(|e| e.to_string())?)
        .map_err(|e| e.to_string())?;

    let args = vec![
        "optimize".into(),
        "allocate".into(),
        "--fields-file".into(),
        fields_file.path().to_string_lossy().into_owned(),
        "--crops-file".into(),
        crops_file.path().to_string_lossy().into_owned(),
        "--weather-file".into(),
        weather_file.path().to_string_lossy().into_owned(),
        "--planning-start".into(),
        planning_start.to_string(),
        "--planning-end".into(),
        planning_end.to_string(),
        "--objective".into(),
        "maximize_profit".into(),
        "--format".into(),
        "json".into(),
        "--max-time".into(),
        "60".into(),
    ];
    let wrapper = AgrrDaemonClient::from_env()
        .execute_daemon_args(&args)
        .map_err(|e| e.to_string())?;
    let exit = wrapper.get("exit_code").and_then(|v| v.as_i64()).unwrap_or(-1);
    if exit != 0 {
        let stderr = wrapper.get("stderr").and_then(|v| v.as_str()).unwrap_or("");
        return Err(format!("exit_code={exit} stderr={stderr}"));
    }
    let stdout = wrapper
        .get("stdout")
        .and_then(|v| v.as_str())
        .filter(|s| !s.trim().is_empty())
        .ok_or_else(|| "empty stdout".to_string())?;
    serde_json::from_str(stdout).map_err(|e| format!("stdout json: {e}"))
}

fn optimize_allocate_inputs(
    pool: &SqlitePool,
    plan_id: i64,
) -> Result<(Vec<Value>, Vec<Value>, Value, Date, Date), String> {
    let read = OptimizationPlanReadSqliteGateway::new(pool.clone());
    let optimization = CultivationPlanOptimizationSqliteGateway::new(pool.clone());
    let snapshot = load_optimization_plan_read_snapshot(&read, plan_id)
        .map_err(|e| e.to_string())?;
    let plan_crops = optimization
        .cultivation_plan_crops_with_crop(plan_id)
        .map_err(|e| e.to_string())?;
    let total_area = snapshot.total_area.unwrap_or(0.0);
    let (fields, crops) =
        OptimizationAllocationInputCalculator::build(total_area, &plan_crops, &SpikeLogger);
    let (planning_start, planning_end) = spike_planning_period(&snapshot)?;
    let weather_location = snapshot
        .weather_location_input
        .as_ref()
        .ok_or_else(|| "weather_location missing on plan".to_string())?;
    let plan_weather = CultivationPlanWeather::new(
        snapshot.plan_id,
        snapshot.prediction_target_end_date,
        snapshot.calculated_planning_end_date,
        snapshot.predicted_weather_data.clone(),
    );
    let weather = existing_prediction_weather_for_allocate(
        pool,
        weather_location,
        snapshot.farm_weather_input.as_ref(),
        &plan_weather,
        planning_end,
    )?;
    Ok((fields, crops, weather, planning_start, planning_end))
}

fn spike_planning_period(snapshot: &OptimizationPlanSnapshot) -> Result<(Date, Date), String> {
    let clock = SystemClock;
    let today = clock.today();
    if snapshot.plan_type_private {
        let start = Date::from_calendar_date(today.year(), time::Month::January, 1)
            .map_err(|e| e.to_string())?;
        let end = Date::from_calendar_date(today.year() + 1, time::Month::December, 31)
            .map_err(|e| e.to_string())?;
        return Ok((start, end));
    }
    let end = snapshot
        .prediction_target_end_date
        .or(snapshot.calculated_planning_end_date)
        .unwrap_or_else(|| {
            Date::from_calendar_date(today.year() + 1, time::Month::December, 31).unwrap_or(today)
        });
    Ok((today, end))
}

fn check_agrr_payload_build(pool: &SqlitePool, plan_id: i64) -> Check {
    match optimize_allocate_inputs(pool, plan_id) {
        Ok((fields, crops, _, _, _)) => {
            let with_stages = crops
                .iter()
                .filter(|c| {
                    c.get("stage_requirements")
                        .and_then(|s| s.as_array())
                        .is_some_and(|a| !a.is_empty())
                })
                .count();
            if fields.is_empty() || crops.is_empty() {
                return Check::fail(
                    "agrr_payload_build",
                    format!("fields={} crops={}", fields.len(), crops.len()),
                );
            }
            Check::pass(
                "agrr_payload_build",
                format!(
                    "fields={} crops={} crops_with_stages={} (OptimizationAllocationInputCalculator)",
                    fields.len(),
                    crops.len(),
                    with_stages
                ),
            )
        }
        Err(e) => Check::fail("agrr_payload_build", e),
    }
}

fn check_allocate(pool: &SqlitePool, plan_id: i64) -> Check {
    let (fields, crops, weather, planning_start, planning_end) =
        match optimize_allocate_inputs(pool, plan_id) {
            Ok(v) => v,
            Err(e) => return Check::fail("agrr_allocate", e),
        };

    if fields.is_empty() || crops.is_empty() {
        return Check::fail(
            "agrr_allocate",
            format!("empty fields={} crops={}", fields.len(), crops.len()),
        );
    }

    if let Some(diag) = probe_allocate_daemon_stderr(&fields, &crops, &weather, planning_start, planning_end) {
        eprintln!("  [diag] {diag}");
    }

    match allocate_via_daemon_stdout(&fields, &crops, &weather, planning_start, planning_end) {
        Ok(result) => {
            let schedules = result
                .get("field_schedules")
                .and_then(|v| v.as_array())
                .map(|a| a.len())
                .unwrap_or(0);
            Check::pass(
                "agrr_allocate",
                format!("field_schedules={schedules} (planning {planning_start}..{planning_end}, stdout path)"),
            )
        }
        Err(e) => {
            let weather_days = weather
                .get("data")
                .and_then(|d| d.as_array())
                .map(|a| a.len())
                .unwrap_or(0);
            Check::fail(
                "agrr_allocate",
                format!("{e} (weather_days={weather_days})"),
            )
        }
    }
}

fn check_allocate_gateway(
    pool: &SqlitePool,
    plan_id: i64,
) -> Check {
    let (fields, crops, weather, planning_start, planning_end) =
        match optimize_allocate_inputs(pool, plan_id) {
            Ok(v) => v,
            Err(e) => return Check::fail("allocate_gateway", e),
        };
    if fields.is_empty() || crops.is_empty() {
        return Check::fail("allocate_gateway", "empty fields or crops");
    }
    let gw = PlanAllocationAllocateAgrrDaemonGateway::from_env();
    match gw.allocate(
        &fields,
        &crops,
        &weather,
        planning_start,
        planning_end,
        None,
        "maximize_profit",
        None,
        false,
    ) {
        Ok(result) => {
            let schedules = result
                .get("field_schedules")
                .and_then(|v| v.as_array())
                .map(|a| a.len())
                .unwrap_or(0);
            Check::pass(
                "allocate_gateway",
                format!("PlanAllocationAllocateAgrrDaemonGateway field_schedules={schedules}"),
            )
        }
        Err(e) => Check::fail("allocate_gateway", e.to_string()),
    }
}

fn main() -> ExitCode {
    let sqlite_path = env::var("AGRR_SQLITE_PATH").unwrap_or_else(|_| {
        "storage/development.sqlite3".to_string()
    });
    let plan_id = plan_id_from_args();

    println!("optimization-chain-spike");
    println!("  AGRR_SQLITE_PATH={sqlite_path}");
    println!("  plan_id={plan_id}");

    let pool = SqlitePool::new(&sqlite_path);
    let weather = shared_weather_gateway(&pool);

    let mut checks = vec![check_daemon()];

    let (plan_check, coords) = check_sqlite_plan_read(&pool, weather.clone(), plan_id);
    checks.push(plan_check);

    if let Some((lat, lon, wl_id)) = coords {
        checks.push(check_weather_api(lat, lon, &pool, weather.clone(), wl_id));
        let read = PlanAllocationAdjustReadSqliteGateway::new(pool.clone(), weather);
        checks.push(check_sqlite_historical_weather(&read, wl_id));
    } else {
        checks.push(Check::fail(
            "weather_daemon_gateway",
            "skipped (no farm coordinates from plan)",
        ));
        checks.push(Check::fail(
            "sqlite_historical_weather",
            "skipped (no weather location)",
        ));
    }

    checks.push(check_agrr_payload_build(&pool, plan_id));
    checks.push(check_allocate_gateway(&pool, plan_id));
    checks.push(check_allocate(&pool, plan_id));

    let mut failed = 0usize;
    for c in &checks {
        let mark = if c.ok { "OK" } else { "NG" };
        println!("  [{mark}] {} — {}", c.name, c.detail);
        if !c.ok {
            failed += 1;
        }
    }

    println!();
    if failed == 0 {
        println!("All checks passed: Rails-parity optimization path is feasible in Rust with existing adapters.");
        ExitCode::SUCCESS
    } else {
        println!("{failed} check(s) failed — see tmp/rust-optimization-spike-report.md");
        ExitCode::from(1)
    }
}
