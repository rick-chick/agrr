//! Ruby: `Adapters::WeatherData::Gateways::InternalWeatherFetchStartActiveRecordGateway`

use crate::pool::SqlitePool;
use crate::shared::internal_api_farm_lookup::{find_farm, InternalApiFarmLookupResult};
use agrr_domain::weather_data::gateways::{
    InternalWeatherFetchStartGateway, StartInternalWeatherFetchResult, WeatherDataGateway,
    WeatherFetchFarmSnapshot,
};

pub struct InternalWeatherFetchStartSqliteGateway<'a> {
    pool: SqlitePool,
    weather_data: &'a dyn WeatherDataGateway,
}

impl<'a> InternalWeatherFetchStartSqliteGateway<'a> {
    pub fn new(pool: SqlitePool, weather_data: &'a dyn WeatherDataGateway) -> Self {
        Self { pool, weather_data }
    }
}

impl InternalWeatherFetchStartGateway for InternalWeatherFetchStartSqliteGateway<'_> {
    fn start_internal_weather_data_fetch(
        &self,
        farm_id: &str,
    ) -> StartInternalWeatherFetchResult {
        let (kind, farm) = find_farm(&self.pool, farm_id);
        if kind != InternalApiFarmLookupResult::Found {
            return StartInternalWeatherFetchResult::FarmNotFound;
        }
        let farm = farm.expect("found");

        let snap = WeatherFetchFarmSnapshot {
            farm_id: farm.id,
            weather_data_status: farm
                .weather_data_status
                .clone()
                .unwrap_or_else(|| "pending".to_string()),
            weather_data_count: None,
            total_blocks: farm.weather_data_total_years.unwrap_or(0),
        };

        if farm.weather_location_id.is_some()
            && farm.weather_data_status.as_deref() == Some("completed")
        {
            let count = match weather_data_count(self.weather_data, farm.weather_location_id) {
                Ok(c) => c,
                Err(message) => return StartInternalWeatherFetchResult::Failed(message),
            };
            return StartInternalWeatherFetchResult::Completed(WeatherFetchFarmSnapshot {
                weather_data_count: Some(count),
                weather_data_status: farm
                    .weather_data_status
                    .unwrap_or_else(|| "completed".to_string()),
                total_blocks: farm.weather_data_total_years.unwrap_or(0),
                ..snap
            });
        }

        StartInternalWeatherFetchResult::NeedsFetch(snap)
    }
}

fn weather_data_count(
    weather_data: &dyn WeatherDataGateway,
    weather_location_id: Option<i64>,
) -> Result<i32, String> {
    let Some(id) = weather_location_id else {
        return Ok(0);
    };
    weather_data
        .weather_data_count(id, None, None)
        .map(|c| c as i32)
        .map_err(|e| e.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::weather_data::WeatherDataSqliteGateway;
    use agrr_domain::weather_data::dtos::WeatherData;
    use agrr_domain::weather_data::gateways::{WeatherDataStorageError, WeatherLocationRecord};
    use serde_json::Value;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicU64, Ordering};
    use time::Date;

    fn temp_pool() -> (SqlitePool, PathBuf) {
        static COUNTER: AtomicU64 = AtomicU64::new(0);
        let n = COUNTER.fetch_add(1, Ordering::Relaxed);
        let path = std::env::temp_dir().join(format!("agrr_internal_fetch_start_{n}.sqlite3"));
        let _ = std::fs::remove_file(&path);
        let pool = SqlitePool::new(path.to_string_lossy());
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE farms (
                    id INTEGER PRIMARY KEY,
                    name TEXT NOT NULL,
                    latitude REAL,
                    longitude REAL,
                    is_reference INTEGER NOT NULL DEFAULT 0,
                    weather_data_status TEXT,
                    weather_data_fetched_years INTEGER,
                    weather_data_total_years INTEGER,
                    weather_data_last_error TEXT,
                    weather_location_id INTEGER
                );
                CREATE TABLE weather_data (
                    id INTEGER PRIMARY KEY,
                    weather_location_id INTEGER NOT NULL,
                    date TEXT NOT NULL
                );
                INSERT INTO farms (id, name, latitude, longitude, is_reference,
                    weather_data_status, weather_data_total_years, weather_location_id)
                VALUES (5, 'Done', 1.0, 2.0, 0, 'completed', 3, 99);
                INSERT INTO weather_data (weather_location_id, date) VALUES (99, '2020-01-01');",
            )
        })
        .expect("schema");
        (pool, path)
    }

    struct FailingCountGateway;

    impl WeatherDataGateway for FailingCountGateway {
        fn weather_data_for_period(
            &self,
            _: i64,
            _: Date,
            _: Date,
        ) -> Result<Vec<WeatherData>, WeatherDataStorageError> {
            Ok(vec![])
        }

        fn weather_data_count(
            &self,
            _: i64,
            _: Option<Date>,
            _: Option<Date>,
        ) -> Result<i64, WeatherDataStorageError> {
            Err(WeatherDataStorageError::new("storage down"))
        }

        fn historical_data_count(
            &self,
            _: i64,
            _: Date,
            _: Date,
        ) -> Result<i64, WeatherDataStorageError> {
            Ok(0)
        }

        fn earliest_date(&self, _: i64) -> Result<Option<Date>, WeatherDataStorageError> {
            Ok(None)
        }

        fn latest_date(&self, _: i64) -> Result<Option<Date>, WeatherDataStorageError> {
            Ok(None)
        }

        fn upsert_weather_data(
            &self,
            _: &[WeatherData],
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
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
            Ok(WeatherLocationRecord { id: 1 })
        }

    }

    #[test]
    fn completed_count_uses_injected_sqlite_gateway() {
        let (pool, _path) = temp_pool();
        let weather = WeatherDataSqliteGateway::new(pool.clone());
        let gw = InternalWeatherFetchStartSqliteGateway::new(pool, &weather);
        let result = gw.start_internal_weather_data_fetch("5");
        let StartInternalWeatherFetchResult::Completed(snap) = result else {
            panic!("expected completed");
        };
        assert_eq!(snap.farm_id, 5);
        assert_eq!(snap.weather_data_count, Some(1));
    }

    #[test]
    fn completed_count_reads_gcs_bulk_without_sqlite_weather_rows() {
        use super::super::gcs_weather_test_support::{
            write_year_fixture, with_local_gcs_root, GcsBulkWeatherGateway,
        };

        with_local_gcs_root(|root| {
            write_year_fixture(
                root,
                99,
                2020,
                r#"{"2020-01-01": {"temperature_max": 1.0, "temperature_min": 0.0}}"#,
            );
            let (pool, _path) = temp_pool();
            pool.with_write(|conn| {
                conn.execute("DELETE FROM weather_data", [])
            })
            .expect("clear sqlite bulk rows");
            let weather = GcsBulkWeatherGateway::from_local_env().expect("gcs");
            let gw = InternalWeatherFetchStartSqliteGateway::new(pool, &weather);
            let result = gw.start_internal_weather_data_fetch("5");
            let StartInternalWeatherFetchResult::Completed(snap) = result else {
                panic!("expected completed, got {result:?}");
            };
            assert_eq!(snap.weather_data_count, Some(1));
        });
    }

    #[test]
    fn completed_returns_failed_on_storage_count_error() {
        let (pool, _path) = temp_pool();
        let failing = FailingCountGateway;
        let gw = InternalWeatherFetchStartSqliteGateway::new(pool, &failing);
        let result = gw.start_internal_weather_data_fetch("5");
        let StartInternalWeatherFetchResult::Failed(msg) = result else {
            panic!("expected failed");
        };
        assert!(msg.contains("storage down"));
    }

    #[test]
    fn needs_fetch_when_not_completed() {
        let path = std::env::temp_dir().join("agrr_internal_fetch_start_pending.sqlite3");
        let _ = std::fs::remove_file(&path);
        let pool = SqlitePool::new(path.to_string_lossy());
        pool.with_write(|conn| {
            conn.execute_batch(
            "CREATE TABLE farms (
                id INTEGER PRIMARY KEY, name TEXT NOT NULL, latitude REAL, longitude REAL,
                is_reference INTEGER NOT NULL DEFAULT 0, weather_data_status TEXT,
                weather_data_fetched_years INTEGER, weather_data_total_years INTEGER,
                weather_data_last_error TEXT, weather_location_id INTEGER
            );
            CREATE TABLE weather_data (
                id INTEGER PRIMARY KEY, weather_location_id INTEGER NOT NULL, date TEXT NOT NULL
            );
            INSERT INTO farms (id, name, latitude, longitude, is_reference, weather_data_status, weather_data_total_years)
            VALUES (6, 'Pending', 1.0, 2.0, 0, 'pending', 4);",
            )
        })
        .expect("schema");
        let weather = WeatherDataSqliteGateway::new(pool.clone());
        let gw = InternalWeatherFetchStartSqliteGateway::new(pool, &weather);
        let result = gw.start_internal_weather_data_fetch("6");
        assert!(matches!(result, StartInternalWeatherFetchResult::NeedsFetch(_)));
    }
}
