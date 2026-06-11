//! GCS bulk + SQLite metadata — Ruby `WeatherDataGcsHttpGateway` + AR for locations.

use agrr_adapters_gcs::{WeatherDataGcsBulkGateway, WeatherDataGcsError};
use agrr_domain::weather_data::dtos::WeatherData;
use agrr_domain::weather_data::gateways::{
    WeatherDataGateway, WeatherDataStorageError, WeatherLocationRecord,
};
use serde_json::Value;
use time::{Date, Month};

use super::weather_bulk_metadata::{plan_count_in_range, plan_historical_count_in_range, RangeCountPlan};
use super::weather_bulk_metadata_gcs_sync::{
    rebuild_bulk_metadata_from_gcs, refresh_bulk_metadata_after_upsert,
};
use super::weather_bulk_metadata_store::WeatherBulkMetadataStore;
use super::weather_data_gateway::WeatherDataSqliteGateway;
use crate::pool::SqlitePool;

pub const STORAGE_ACTIVE_RECORD: &str = "active_record";
pub const STORAGE_GCS: &str = "gcs";

fn gcs_storage_err(e: WeatherDataGcsError) -> WeatherDataStorageError {
    WeatherDataStorageError::new(e.to_string())
}

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

pub struct WeatherDataGatewayBundle {
    pool: SqlitePool,
    sqlite: WeatherDataSqliteGateway,
    gcs: Option<WeatherDataGcsBulkGateway>,
}

impl WeatherDataGatewayBundle {
    pub fn resolve(pool: SqlitePool) -> Result<Self, WeatherDataGcsError> {
        let storage =
            std::env::var("WEATHER_DATA_STORAGE").unwrap_or_else(|_| STORAGE_ACTIVE_RECORD.into());
        let sqlite = WeatherDataSqliteGateway::new(pool.clone());
        let gcs = if storage == STORAGE_GCS {
            Some(WeatherDataGcsBulkGateway::from_env()?)
        } else {
            None
        };
        Ok(Self { pool, sqlite, gcs })
    }

    pub fn sqlite(&self) -> &WeatherDataSqliteGateway {
        &self.sqlite
    }

    fn metadata_store(&self) -> WeatherBulkMetadataStore {
        WeatherBulkMetadataStore::new(self.pool.clone())
    }

    fn try_rebuild_bulk_metadata(&self, weather_location_id: i64) {
        if let Err(err) = self.rebuild_bulk_metadata(weather_location_id) {
            tracing::warn!(
                weather_location_id,
                error = %err,
                "weather bulk metadata rebuild failed after GCS fallback"
            );
        }
    }

    /// Rebuild `weather_locations.bulk_*` from GCS year files (`WEATHER_DATA_STORAGE=gcs`).
    pub fn rebuild_bulk_metadata(&self, weather_location_id: i64) -> Result<(), String> {
        let Some(gcs) = &self.gcs else {
            return Err("WEATHER_DATA_STORAGE is not gcs".into());
        };
        rebuild_bulk_metadata_from_gcs(gcs, &self.metadata_store(), weather_location_id)
    }

    pub fn weather_location_ids_missing_bulk_metadata(&self) -> Result<Vec<i64>, String> {
        self.pool
            .with_read(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT id FROM weather_locations \
                     WHERE bulk_year_stats IS NULL OR trim(bulk_year_stats) = ''",
                )?;
                let rows = stmt.query_map([], |row| row.get(0))?;
                let mut ids = Vec::new();
                for row in rows {
                    ids.push(row?);
                }
                Ok(ids)
            })
            .map_err(|e| e.to_string())
    }

    pub fn rebuild_missing_bulk_metadata(&self) -> Result<usize, String> {
        let ids = self.weather_location_ids_missing_bulk_metadata()?;
        let count = ids.len();
        for id in ids {
            self.rebuild_bulk_metadata(id)?;
        }
        Ok(count)
    }

    fn weather_data_count_with_metadata(
        &self,
        gcs: &WeatherDataGcsBulkGateway,
        weather_location_id: i64,
        start_date: Option<Date>,
        end_date: Option<Date>,
    ) -> Result<i64, WeatherDataStorageError> {
        let metadata = match self.metadata_store().load(weather_location_id) {
            Ok(Some(metadata)) => metadata,
            Ok(None) => {
                let count = gcs
                    .weather_data_count(weather_location_id, start_date, end_date)
                    .map_err(gcs_storage_err)?;
                self.try_rebuild_bulk_metadata(weather_location_id);
                return Ok(count);
            }
            Err(err) => return Err(WeatherDataStorageError::new(err)),
        };
        match plan_count_in_range(&metadata, start_date, end_date) {
            RangeCountPlan::Exact(count) => Ok(count),
            RangeCountPlan::MissingMetadata => {
                let count = gcs
                    .weather_data_count(weather_location_id, start_date, end_date)
                    .map_err(gcs_storage_err)?;
                self.try_rebuild_bulk_metadata(weather_location_id);
                Ok(count)
            }
            RangeCountPlan::PartialYears {
                full_year_total,
                years,
            } => {
                let (Some(start), Some(end)) = (start_date, end_date) else {
                    return gcs
                        .weather_data_count(weather_location_id, start_date, end_date)
                        .map_err(gcs_storage_err);
                };
                let partial = count_years_from_gcs(
                    gcs,
                    weather_location_id,
                    start,
                    end,
                    &years,
                    false,
                )?;
                Ok(full_year_total + partial)
            }
        }
    }

    fn historical_data_count_with_metadata(
        &self,
        gcs: &WeatherDataGcsBulkGateway,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<i64, WeatherDataStorageError> {
        let metadata = match self.metadata_store().load(weather_location_id) {
            Ok(Some(metadata)) => metadata,
            Ok(None) => {
                let count = gcs
                    .historical_data_count(weather_location_id, start_date, end_date)
                    .map_err(gcs_storage_err)?;
                self.try_rebuild_bulk_metadata(weather_location_id);
                return Ok(count);
            }
            Err(err) => return Err(WeatherDataStorageError::new(err)),
        };
        match plan_historical_count_in_range(&metadata, start_date, end_date) {
            RangeCountPlan::Exact(count) => Ok(count),
            RangeCountPlan::MissingMetadata => {
                let count = gcs
                    .historical_data_count(weather_location_id, start_date, end_date)
                    .map_err(gcs_storage_err)?;
                self.try_rebuild_bulk_metadata(weather_location_id);
                Ok(count)
            }
            RangeCountPlan::PartialYears {
                full_year_total,
                years,
            } => {
                let partial = count_years_from_gcs(
                    gcs,
                    weather_location_id,
                    start_date,
                    end_date,
                    &years,
                    true,
                )?;
                Ok(full_year_total + partial)
            }
        }
    }
}

fn count_years_from_gcs(
    gcs: &WeatherDataGcsBulkGateway,
    weather_location_id: i64,
    start: Date,
    end: Date,
    years: &[i32],
    historical: bool,
) -> Result<i64, WeatherDataStorageError> {
    let mut total = 0i64;
    for &year in years {
        let range_start = start.max(calendar_year_start(year).unwrap_or(start));
        let range_end = end.min(calendar_year_end(year).unwrap_or(end));
        if range_start > range_end {
            continue;
        }
        let count = if historical {
            gcs.historical_data_count(weather_location_id, range_start, range_end)
        } else {
            gcs.weather_data_count(
                weather_location_id,
                Some(range_start),
                Some(range_end),
            )
        }
        .map_err(gcs_storage_err)?;
        total += count;
    }
    Ok(total)
}

fn calendar_year_start(year: i32) -> Option<Date> {
    Date::from_calendar_date(year, Month::January, 1).ok()
}

fn calendar_year_end(year: i32) -> Option<Date> {
    Date::from_calendar_date(year, Month::December, 31).ok()
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
            self.weather_data_count_with_metadata(gcs, weather_location_id, start_date, end_date)
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
            self.historical_data_count_with_metadata(gcs, weather_location_id, start_date, end_date)
        } else {
            self.sqlite
                .historical_data_count(weather_location_id, start_date, end_date)
        }
    }

    fn earliest_date(
        &self,
        weather_location_id: i64,
    ) -> Result<Option<Date>, WeatherDataStorageError> {
        if self.gcs.is_some() {
            if let Ok(Some(date)) = self
                .metadata_store()
                .earliest_date(weather_location_id)
                .map_err(WeatherDataStorageError::new)
            {
                return Ok(Some(date));
            }
            if let Some(gcs) = &self.gcs {
                let date = gcs.earliest_date(weather_location_id).map_err(gcs_storage_err)?;
                if date.is_some() {
                    self.try_rebuild_bulk_metadata(weather_location_id);
                }
                return Ok(date);
            }
        }
        self.sqlite.earliest_date(weather_location_id)
    }

    fn latest_date(
        &self,
        weather_location_id: i64,
    ) -> Result<Option<Date>, WeatherDataStorageError> {
        if self.gcs.is_some() {
            if let Ok(Some(date)) = self
                .metadata_store()
                .latest_date(weather_location_id)
                .map_err(WeatherDataStorageError::new)
            {
                return Ok(Some(date));
            }
            if let Some(gcs) = &self.gcs {
                let date = gcs.latest_date(weather_location_id).map_err(gcs_storage_err)?;
                if date.is_some() {
                    self.try_rebuild_bulk_metadata(weather_location_id);
                }
                return Ok(date);
            }
        }
        self.sqlite.latest_date(weather_location_id)
    }

    fn upsert_weather_data(
        &self,
        weather_data_dtos: &[WeatherData],
        weather_location_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(gcs) = &self.gcs {
            gcs.upsert_weather_data(weather_data_dtos, weather_location_id)
                .map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)?;
            let store = self.metadata_store();
            refresh_bulk_metadata_after_upsert(gcs, &store, weather_location_id, weather_data_dtos)
                .map_err(|e| -> Box<dyn std::error::Error + Send + Sync> { e.into() })?;
            Ok(())
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

}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::weather_data::weather_bulk_metadata::{WeatherBulkMetadata, WeatherYearStats};
    use agrr_adapters_gcs::GcsIoSnapshot;
    use std::collections::BTreeMap;
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

    fn test_pool_with_location() -> (SqlitePool, i64) {
        let path = std::env::temp_dir().join(format!(
            "agrr_bundle_meta_{}_{}.sqlite3",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let _ = std::fs::remove_file(&path);
        let pool = SqlitePool::new(path.to_string_lossy());
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE weather_locations (
                    id INTEGER PRIMARY KEY,
                    latitude REAL,
                    longitude REAL,
                    created_at TEXT NOT NULL DEFAULT '1970-01-01',
                    updated_at TEXT NOT NULL DEFAULT '1970-01-01',
                    bulk_earliest_date TEXT,
                    bulk_latest_date TEXT,
                    bulk_year_stats TEXT
                );",
            )?;
            conn.execute(
                "INSERT INTO weather_locations (id, latitude, longitude) VALUES (9, 35.0, 139.0)",
                [],
            )?;
            Ok(())
        })
        .expect("schema");
        (pool, 9)
    }

    fn prepopulated_metadata() -> WeatherBulkMetadata {
        WeatherBulkMetadata {
            earliest_date: Some("2023-01-01".into()),
            latest_date: Some("2024-12-31".into()),
            years: BTreeMap::from([
                (
                    "2023".into(),
                    WeatherYearStats {
                        count: 365,
                        historical_count: 365,
                        first_date: "2023-01-01".into(),
                        last_date: "2023-12-31".into(),
                    },
                ),
                (
                    "2024".into(),
                    WeatherYearStats {
                        count: 366,
                        historical_count: 366,
                        first_date: "2024-01-01".into(),
                        last_date: "2024-12-31".into(),
                    },
                ),
            ]),
        }
    }

    #[test]
    fn aggregate_queries_use_prepopulated_metadata_without_gcs_io() {
        let _guard = ENV_LOCK.lock().unwrap();
        let dir = tempfile::tempdir().unwrap();
        std::env::set_var("WEATHER_DATA_STORAGE", STORAGE_GCS);
        std::env::set_var("GCS_BUCKET", "test-bucket");
        std::env::set_var("WEATHER_DATA_LOCAL_ROOT", dir.path());

        let (pool, location_id) = test_pool_with_location();
        WeatherBulkMetadataStore::new(pool.clone())
            .save(location_id, &prepopulated_metadata())
            .expect("save metadata");

        let before = GcsIoSnapshot::capture();
        let bundle = WeatherDataGatewayBundle::resolve(pool).expect("bundle");
        bundle
            .latest_date(location_id)
            .expect("latest date via metadata path");
        bundle
            .weather_data_count(
                location_id,
                Some(Date::from_calendar_date(2023, Month::January, 1).unwrap()),
                Some(Date::from_calendar_date(2024, Month::December, 31).unwrap()),
            )
            .expect("count via metadata path");
        let (reads, lists, writes) = before.delta_since();

        std::env::remove_var("WEATHER_DATA_STORAGE");
        std::env::remove_var("GCS_BUCKET");
        std::env::remove_var("WEATHER_DATA_LOCAL_ROOT");

        assert_eq!((reads, lists, writes), (0, 0, 0));
    }
}
