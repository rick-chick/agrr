//! Ruby: `Adapters::WeatherData::Gateways::InternalWeatherFetchStartActiveRecordGateway`

use crate::pool::SqlitePool;
use crate::shared::internal_api_farm_lookup::{find_farm, InternalApiFarmLookupResult};
use agrr_domain::weather_data::gateways::{
    InternalWeatherFetchStartGateway, StartInternalWeatherFetchResult, WeatherFetchFarmSnapshot,
};
use rusqlite::params;

pub struct InternalWeatherFetchStartSqliteGateway {
    pool: SqlitePool,
}

impl InternalWeatherFetchStartSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl InternalWeatherFetchStartGateway for InternalWeatherFetchStartSqliteGateway {
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
            let count = weather_data_count(&self.pool, farm.weather_location_id);
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

fn weather_data_count(pool: &SqlitePool, weather_location_id: Option<i64>) -> i32 {
    let Some(id) = weather_location_id else {
        return 0;
    };
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT COUNT(*) FROM weather_data WHERE weather_location_id = ?1",
            params![id],
            |row| row.get::<_, i64>(0),
        )
    })
    .ok()
    .map(|c| c as i32)
    .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicU64, Ordering};

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

    #[test]
    fn completed_when_location_and_status_completed() {
        let (pool, _path) = temp_pool();
        let gw = InternalWeatherFetchStartSqliteGateway::new(pool);
        let result = gw.start_internal_weather_data_fetch("5");
        let StartInternalWeatherFetchResult::Completed(snap) = result else {
            panic!("expected completed");
        };
        assert_eq!(snap.farm_id, 5);
        assert_eq!(snap.weather_data_count, Some(1));
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
        let gw = InternalWeatherFetchStartSqliteGateway::new(pool);
        let result = gw.start_internal_weather_data_fetch("6");
        assert!(matches!(result, StartInternalWeatherFetchResult::NeedsFetch(_)));
    }
}
