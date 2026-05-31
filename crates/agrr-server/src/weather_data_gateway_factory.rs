//! Ruby: `Adapters::WeatherData::WeatherDataGatewayFactory`

use agrr_adapters_gcs::{WeatherDataGcsBulkGateway, WeatherDataGcsError};
use agrr_adapters_sqlite::{SqlitePool, WeatherDataSqliteGateway};
use agrr_domain::weather_data::dtos::WeatherData;
use agrr_domain::weather_data::gateways::{
    WeatherDataGateway, WeatherDataStorageError, WeatherLocationRecord,
};
use serde_json::Value;
use time::Date;

pub const STORAGE_ACTIVE_RECORD: &str = "active_record";
pub const STORAGE_GCS: &str = "gcs";

/// Fail-fast when `WEATHER_DATA_STORAGE=gcs` without bucket configuration.
pub fn validate_weather_storage_config() -> Result<(), String> {
    let storage =
        std::env::var("WEATHER_DATA_STORAGE").unwrap_or_else(|_| STORAGE_ACTIVE_RECORD.into());
    if storage != STORAGE_GCS {
        return Ok(());
    }
    let has_bucket = std::env::var("GCS_WEATHER_DATA_BUCKET").is_ok()
        || std::env::var("GCS_BUCKET").is_ok();
    if !has_bucket {
        return Err(
            "WEATHER_DATA_STORAGE=gcs requires GCS_BUCKET or GCS_WEATHER_DATA_BUCKET".into(),
        );
    }
    if std::env::var("WEATHER_DATA_LOCAL_ROOT").ok().is_none() {
        tracing::info!(
            "WEATHER_DATA_STORAGE=gcs: remote GCS via ADC (bulk reads/writes; SQLite holds metadata only)"
        );
    }
    Ok(())
}

fn gcs_storage_err(e: WeatherDataGcsError) -> WeatherDataStorageError {
    WeatherDataStorageError::new(e.to_string())
}

/// GCS bulk + SQLite metadata — Ruby `WeatherDataGcsHttpGateway` + AR for locations.
pub struct WeatherDataGatewayBundle {
    sqlite: WeatherDataSqliteGateway,
    gcs: Option<WeatherDataGcsBulkGateway>,
}

impl WeatherDataGatewayBundle {
    pub fn resolve(pool: SqlitePool) -> Result<Self, WeatherDataGcsError> {
        let storage =
            std::env::var("WEATHER_DATA_STORAGE").unwrap_or_else(|_| STORAGE_ACTIVE_RECORD.into());
        let sqlite = WeatherDataSqliteGateway::new(pool);
        let gcs = if storage == STORAGE_GCS {
            Some(WeatherDataGcsBulkGateway::from_env()?)
        } else {
            None
        };
        Ok(Self { sqlite, gcs })
    }

    pub fn sqlite(&self) -> &WeatherDataSqliteGateway {
        &self.sqlite
    }
}

impl WeatherDataGateway for WeatherDataGatewayBundle {
    fn weather_data_for_period(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<Vec<WeatherData>, WeatherDataStorageError> {
        if let Some(gcs) = &self.gcs {
            gcs.weather_data_for_period(weather_location_id, start_date, end_date)
                .map_err(gcs_storage_err)
        } else {
            self.sqlite
                .weather_data_for_period(weather_location_id, start_date, end_date)
        }
    }

    fn weather_data_count(
        &self,
        weather_location_id: i64,
        start_date: Option<Date>,
        end_date: Option<Date>,
    ) -> Result<i64, WeatherDataStorageError> {
        if let Some(gcs) = &self.gcs {
            gcs.weather_data_count(weather_location_id, start_date, end_date)
                .map_err(gcs_storage_err)
        } else {
            self.sqlite
                .weather_data_count(weather_location_id, start_date, end_date)
        }
    }

    fn historical_data_count(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<i64, WeatherDataStorageError> {
        if let Some(gcs) = &self.gcs {
            gcs.historical_data_count(weather_location_id, start_date, end_date)
                .map_err(gcs_storage_err)
        } else {
            self.sqlite
                .historical_data_count(weather_location_id, start_date, end_date)
        }
    }

    fn earliest_date(
        &self,
        weather_location_id: i64,
    ) -> Result<Option<Date>, WeatherDataStorageError> {
        if let Some(gcs) = &self.gcs {
            gcs.earliest_date(weather_location_id)
                .map_err(gcs_storage_err)
        } else {
            self.sqlite.earliest_date(weather_location_id)
        }
    }

    fn latest_date(
        &self,
        weather_location_id: i64,
    ) -> Result<Option<Date>, WeatherDataStorageError> {
        if let Some(gcs) = &self.gcs {
            gcs.latest_date(weather_location_id)
                .map_err(gcs_storage_err)
        } else {
            self.sqlite.latest_date(weather_location_id)
        }
    }

    fn upsert_weather_data(
        &self,
        weather_data_dtos: &[WeatherData],
        weather_location_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(gcs) = &self.gcs {
            gcs.upsert_weather_data(weather_data_dtos, weather_location_id)
                .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
        } else {
            self.sqlite
                .upsert_weather_data(weather_data_dtos, weather_location_id)
        }
    }

    fn find_by_coordinates(
        &self,
        latitude: f64,
        longitude: f64,
    ) -> Option<WeatherLocationRecord> {
        self.sqlite.find_by_coordinates(latitude, longitude)
    }

    fn find_or_create_weather_location(
        &self,
        latitude: f64,
        longitude: f64,
        elevation: Option<f64>,
        timezone: Option<&str>,
    ) -> Result<WeatherLocationRecord, Box<dyn std::error::Error + Send + Sync>> {
        self.sqlite
            .find_or_create_weather_location(latitude, longitude, elevation, timezone)
    }

    fn update_predicted_weather_data(
        &self,
        weather_location_id: i64,
        payload: &Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.sqlite
            .update_predicted_weather_data(weather_location_id, payload)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    #[test]
    fn validate_accepts_active_record_without_bucket() {
        let _guard = ENV_LOCK.lock().unwrap();
        std::env::remove_var("WEATHER_DATA_STORAGE");
        std::env::remove_var("GCS_BUCKET");
        assert!(validate_weather_storage_config().is_ok());
    }

    #[test]
    fn validate_requires_bucket_when_gcs() {
        let _guard = ENV_LOCK.lock().unwrap();
        std::env::set_var("WEATHER_DATA_STORAGE", STORAGE_GCS);
        std::env::remove_var("GCS_BUCKET");
        std::env::remove_var("GCS_WEATHER_DATA_BUCKET");
        let err = validate_weather_storage_config().expect_err("missing bucket");
        assert!(err.contains("GCS_BUCKET"));
        std::env::remove_var("WEATHER_DATA_STORAGE");
    }

    #[test]
    fn validate_ok_when_gcs_and_bucket_set() {
        let _guard = ENV_LOCK.lock().unwrap();
        std::env::set_var("WEATHER_DATA_STORAGE", STORAGE_GCS);
        std::env::set_var("GCS_BUCKET", "test-bucket");
        assert!(validate_weather_storage_config().is_ok());
        std::env::remove_var("WEATHER_DATA_STORAGE");
        std::env::remove_var("GCS_BUCKET");
    }
}
