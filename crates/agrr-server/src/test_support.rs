//! Shared test fixtures for `agrr-server` integration tests.

use crate::cable::CableHub;
use crate::farm_weather_fetch_locks::FarmWeatherFetchLocks;
use crate::plan_task_schedule_regen_locks::PlanTaskScheduleRegenLocks;
use crate::jobs::JobChainDispatcher;
use crate::state::DEFAULT_OPTIMIZATION_MAX_CONCURRENT_CHAINS;
use crate::locale_catalog::LocaleCatalog;
use crate::masters_rate_limit::{MastersRateLimitConfig, MastersRateLimiter};
use crate::state::AppState;
use agrr_adapters_sqlite::{PredictedWeatherGatewayBundle, SqlitePool};
use agrr_domain::weather_data::gateways::WeatherDataGateway;
use std::sync::Arc;
use tempfile::NamedTempFile;

pub struct TestDb {
    pub pool: SqlitePool,
    _file: NamedTempFile,
}

pub fn test_pool_with_plan(plan_id: i64) -> TestDb {
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
               weather_location_id INTEGER,
               is_reference INTEGER NOT NULL DEFAULT 0
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
               task_schedule_sync_state TEXT NOT NULL DEFAULT 'never',
               task_schedule_sync_error TEXT,
               task_schedule_sync_error_crop_id INTEGER,
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
    TestDb { pool, _file: file }
}

/// Schema without `optimization_phase` columns — `StartOptimizing` cannot persist.
pub fn test_pool_without_optimization_phase_column(plan_id: i64) -> TestDb {
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
               weather_location_id INTEGER,
               is_reference INTEGER NOT NULL DEFAULT 0
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
    TestDb { pool, _file: file }
}

/// Plan with `status = optimizing` (for chain guard / phase step tests).
pub fn test_pool_with_optimizing_plan(plan_id: i64) -> TestDb {
    let db = test_pool_with_plan(plan_id);
    db.pool
        .with_write(|conn| {
            conn.execute(
                "UPDATE cultivation_plans SET status = 'optimizing' WHERE id = ?1",
                rusqlite::params![plan_id],
            )?;
            Ok(())
        })
        .expect("set optimizing");
    db
}

/// Minimal plan row for task schedule sync-state tests (no farm / field graph).
pub fn test_pool_with_sync_plan(plan_id: i64) -> TestDb {
    let file = NamedTempFile::new().expect("temp db");
    let path = file.path().to_str().expect("utf8 path");
    let pool = SqlitePool::new(path);
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE cultivation_plans (
               id INTEGER PRIMARY KEY,
               task_schedule_sync_state TEXT NOT NULL DEFAULT 'never',
               task_schedule_sync_error TEXT,
               task_schedule_sync_error_crop_id INTEGER,
               updated_at TEXT DEFAULT (datetime('now'))
             );",
        )?;
        conn.execute(
            "INSERT INTO cultivation_plans (id, task_schedule_sync_state)
             VALUES (?1, 'never')",
            rusqlite::params![plan_id],
        )?;
        Ok(())
    })
    .expect("seed");
    TestDb { pool, _file: file }
}

pub fn test_app_state(pool: SqlitePool) -> AppState {
    struct NoopWeather;
    impl WeatherDataGateway for NoopWeather {
        fn weather_data_for_period(
            &self,
            _: i64,
            _: time::Date,
            _: time::Date,
        ) -> Result<Vec<agrr_domain::weather_data::dtos::WeatherData>, agrr_domain::weather_data::gateways::WeatherDataStorageError> {
            Ok(vec![])
        }
        fn weather_data_count(
            &self,
            _: i64,
            _: Option<time::Date>,
            _: Option<time::Date>,
        ) -> Result<i64, agrr_domain::weather_data::gateways::WeatherDataStorageError> {
            Ok(0)
        }
        fn historical_data_count(
            &self,
            _: i64,
            _: time::Date,
            _: time::Date,
        ) -> Result<i64, agrr_domain::weather_data::gateways::WeatherDataStorageError> {
            Ok(0)
        }
        fn earliest_date(
            &self,
            _: i64,
        ) -> Result<Option<time::Date>, agrr_domain::weather_data::gateways::WeatherDataStorageError> {
            Ok(None)
        }
        fn latest_date(
            &self,
            _: i64,
        ) -> Result<Option<time::Date>, agrr_domain::weather_data::gateways::WeatherDataStorageError> {
            Ok(None)
        }
        fn upsert_weather_data(
            &self,
            _: &[agrr_domain::weather_data::dtos::WeatherData],
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
        fn find_by_coordinates(
            &self,
            _: f64,
            _: f64,
        ) -> Option<agrr_domain::weather_data::gateways::WeatherLocationRecord> {
            None
        }
        fn find_or_create_weather_location(
            &self,
            _: f64,
            _: f64,
            _: Option<f64>,
            _: Option<&str>,
        ) -> Result<agrr_domain::weather_data::gateways::WeatherLocationRecord, Box<dyn std::error::Error + Send + Sync>>
        {
            Err("not used".into())
        }

    }

    let predicted_weather = PredictedWeatherGatewayBundle::resolve(pool.clone())
        .unwrap_or_else(|e| panic!("predicted weather gateway bundle: {e}"));

    AppState {
        sqlite: pool,
        weather_data: Arc::new(NoopWeather),
        predicted_weather,
        google_client_id: Arc::new(String::new()),
        google_client_secret: Arc::new(String::new()),
        scheduler_auth_token: Arc::new(String::new()),
        backdoor_token: Arc::new(String::new()),
        secure_cookies: false,
        weather_fetch_job_dispatcher: Arc::new(JobChainDispatcher::new()),
        optimization_chain_dispatcher: Arc::new(JobChainDispatcher::with_max_concurrent_chains(
            Some(DEFAULT_OPTIMIZATION_MAX_CONCURRENT_CHAINS),
        )),
        task_schedule_regen_dispatcher: Arc::new(JobChainDispatcher::new()),
        task_schedule_regen_tokens: Arc::new(std::sync::Mutex::new(std::collections::HashMap::new())),
        plan_task_schedule_regen_locks: PlanTaskScheduleRegenLocks::new(),
        farm_weather_fetch_locks: FarmWeatherFetchLocks::new(),
        cable_hub: Arc::new(CableHub::default()),
        locale_catalog: Arc::new(LocaleCatalog::from_pairs(
            "ja",
            &[(
                "models.cultivation_plan.phases.fetching_weather",
                "Fetching weather",
            )],
        )),
        masters_rate_limit: Arc::new(MastersRateLimiter::new(MastersRateLimitConfig::from_env())),
    }
}

