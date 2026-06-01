//! Shared test fixtures for `agrr-server` integration tests.

use crate::cable::CableHub;
use crate::jobs::JobChainDispatcher;
use crate::locale_catalog::LocaleCatalog;
use crate::state::AppState;
use agrr_adapters_sqlite::SqlitePool;
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
            "CREATE TABLE farms (id INTEGER PRIMARY KEY, name TEXT);
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
        conn.execute("INSERT INTO farms (id, name) VALUES (1, 'Test Farm')", [])?;
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

        fn update_predicted_weather_data(
            &self,
            _: i64,
            _: &serde_json::Value,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    AppState {
        sqlite: pool,
        weather_data: Arc::new(NoopWeather),
        google_client_id: Arc::new(String::new()),
        google_client_secret: Arc::new(String::new()),
        scheduler_auth_token: Arc::new(String::new()),
        backdoor_token: Arc::new(String::new()),
        secure_cookies: false,
        weather_fetch_job_dispatcher: Arc::new(JobChainDispatcher::new()),
        optimization_chain_dispatcher: Arc::new(JobChainDispatcher::new()),
        cable_hub: Arc::new(CableHub::default()),
        locale_catalog: Arc::new(LocaleCatalog::from_pairs(
            "ja",
            &[(
                "models.cultivation_plan.phases.fetching_weather",
                "Fetching weather",
            )],
        )),
    }
}

pub fn read_optimization_phase(pool: &SqlitePool, plan_id: i64) -> Option<String> {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT optimization_phase FROM cultivation_plans WHERE id = ?1",
            rusqlite::params![plan_id],
            |row| row.get(0),
        )
    })
    .ok()
}

pub fn wait_until(timeout: std::time::Duration, mut condition: impl FnMut() -> bool) -> bool {
    let deadline = std::time::Instant::now() + timeout;
    while std::time::Instant::now() < deadline {
        if condition() {
            return true;
        }
        std::thread::sleep(std::time::Duration::from_millis(10));
    }
    false
}
