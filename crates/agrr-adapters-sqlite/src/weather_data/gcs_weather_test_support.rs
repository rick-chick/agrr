//! Shared GCS local_root fixtures for sqlite adapter tests (`WEATHER_DATA_STORAGE=gcs` parity).

use agrr_adapters_gcs::{WeatherDataGcsBulkGateway, WeatherDataGcsError};
use agrr_domain::weather_data::dtos::WeatherData;
use agrr_domain::weather_data::gateways::{
    WeatherDataGateway, WeatherDataStorageError, WeatherLocationRecord,
};
use serde_json::Value;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use time::Date;

static ENV_LOCK: Mutex<()> = Mutex::new(());

/// Runs `f` with `GCS_BUCKET` + `WEATHER_DATA_LOCAL_ROOT` set; restores env afterward.
pub fn with_local_gcs_root<F>(f: F)
where
    F: FnOnce(&Path),
{
    let _guard = ENV_LOCK.lock().expect("env lock");
    let dir = tempfile::tempdir().expect("tempdir");
    std::env::set_var("GCS_BUCKET", "test-bucket");
    std::env::set_var("WEATHER_DATA_LOCAL_ROOT", dir.path());
    f(dir.path());
    std::env::remove_var("GCS_BUCKET");
    std::env::remove_var("WEATHER_DATA_LOCAL_ROOT");
}

pub fn write_year_fixture(root: &Path, weather_location_id: i64, year: i32, payload: &str) {
    let key = WeatherDataGcsBulkGateway::object_key(weather_location_id, year);
    let path = root.join(&key);
    std::fs::create_dir_all(path.parent().expect("parent")).expect("mkdir");
    let mut file = std::fs::File::create(&path).expect("create");
    write!(file, "{payload}").expect("write");
}

/// GCS bulk reads only — metadata methods are unavailable (same as production bundle bulk half).
pub struct GcsBulkWeatherGateway(WeatherDataGcsBulkGateway);

impl GcsBulkWeatherGateway {
    pub fn from_local_env() -> Result<Self, WeatherDataGcsError> {
        WeatherDataGcsBulkGateway::from_env().map(Self)
    }
}

fn gcs_err(e: WeatherDataGcsError) -> WeatherDataStorageError {
    WeatherDataStorageError::new(e.to_string())
}

impl WeatherDataGateway for GcsBulkWeatherGateway {
    fn weather_data_for_period(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<Vec<WeatherData>, WeatherDataStorageError> {
        self.0
            .weather_data_for_period(weather_location_id, start_date, end_date)
            .map_err(gcs_err)
    }

    fn weather_data_count(
        &self,
        weather_location_id: i64,
        start_date: Option<Date>,
        end_date: Option<Date>,
    ) -> Result<i64, WeatherDataStorageError> {
        self.0
            .weather_data_count(weather_location_id, start_date, end_date)
            .map_err(gcs_err)
    }

    fn historical_data_count(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<i64, WeatherDataStorageError> {
        self.0
            .historical_data_count(weather_location_id, start_date, end_date)
            .map_err(gcs_err)
    }

    fn earliest_date(
        &self,
        weather_location_id: i64,
    ) -> Result<Option<Date>, WeatherDataStorageError> {
        self.0
            .earliest_date(weather_location_id)
            .map_err(gcs_err)
    }

    fn latest_date(
        &self,
        weather_location_id: i64,
    ) -> Result<Option<Date>, WeatherDataStorageError> {
        self.0
            .latest_date(weather_location_id)
            .map_err(gcs_err)
    }

    fn upsert_weather_data(
        &self,
        weather_data_dtos: &[WeatherData],
        weather_location_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.0
            .upsert_weather_data(weather_data_dtos, weather_location_id)
            .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
    }

    fn find_by_coordinates(&self, _: f64, _: f64) -> Option<WeatherLocationRecord> {
        None
    }

    fn find_or_create_weather_location(
        &self,
        _: f64,
        _: f64,
        _: Option<f64>,
        _: Option<&str>,
    ) -> Result<WeatherLocationRecord, Box<dyn std::error::Error + Send + Sync>> {
        Err("GCS bulk gateway does not manage weather_locations".into())
    }

    fn update_predicted_weather_data(
        &self,
        _: i64,
        _: &Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        Err("GCS bulk gateway does not store predicted weather".into())
    }
}

pub fn temp_pool_farms_only() -> (crate::SqlitePool, PathBuf) {
    use std::sync::atomic::{AtomicU64, Ordering};
    static COUNTER: AtomicU64 = AtomicU64::new(0);
    let n = COUNTER.fetch_add(1, Ordering::Relaxed);
    let path = std::env::temp_dir().join(format!("agrr_sqlite_gcs_test_{n}.sqlite3"));
    let _ = std::fs::remove_file(&path);
    let pool = crate::SqlitePool::new(path.to_string_lossy());
    pool.with_write(|conn| {
        conn.execute_batch(
            "CREATE TABLE farms (
              id INTEGER PRIMARY KEY,
              user_id INTEGER,
              name TEXT NOT NULL,
              latitude REAL,
              longitude REAL,
              is_reference INTEGER NOT NULL DEFAULT 0,
              weather_data_status TEXT,
              weather_data_fetched_years INTEGER,
              weather_data_total_years INTEGER,
              weather_data_last_error TEXT,
              weather_location_id INTEGER
            );",
        )
    })
    .expect("farms schema");
    (pool, path)
}
