//! Ruby: `Adapters::WeatherData::Gateways::InternalFarmWeatherReadActiveRecordGateway` (parity via domain gateway)

use crate::pool::SqlitePool;
use crate::shared::internal_api_farm_lookup::{find_farm, InternalApiFarmLookupResult};
use agrr_domain::farm::entities::FarmEntity;
use agrr_domain::weather_data::dtos::{
    InternalFarmWeatherDataListOutput, InternalFarmWeatherDataListResult,
    InternalFarmWeatherStatusOutput, InternalFarmWeatherStatusResult,
};
use agrr_domain::weather_data::gateways::InternalFarmWeatherReadGateway;
use rusqlite::params;
use serde_json::{json, Value};

pub struct InternalFarmWeatherReadSqliteGateway {
    pool: SqlitePool,
}

impl InternalFarmWeatherReadSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl InternalFarmWeatherReadGateway for InternalFarmWeatherReadSqliteGateway {
    fn weather_status_snapshot(
        &self,
        farm_id: &str,
    ) -> InternalFarmWeatherStatusResult {
        let (kind, farm) = find_farm(&self.pool, farm_id);
        if kind != InternalApiFarmLookupResult::Found {
            return InternalFarmWeatherStatusResult::farm_not_found();
        }
        let farm = farm.expect("found");

        let weather_data_count = weather_data_count_for_farm(&self.pool, farm.weather_location_id);
        let progress = farm_entity_progress(&farm);

        InternalFarmWeatherStatusResult::ok(InternalFarmWeatherStatusOutput {
            farm_id: farm.id,
            status: farm
                .weather_data_status
                .unwrap_or_else(|| "pending".to_string()),
            progress,
            fetched_blocks: farm.weather_data_fetched_years.unwrap_or(0),
            total_blocks: farm.weather_data_total_years.unwrap_or(0),
            weather_data_count,
            last_error: farm.weather_data_last_error,
        })
    }

    fn weather_data_list_snapshot(
        &self,
        farm_id: &str,
    ) -> InternalFarmWeatherDataListResult {
        let (kind, farm) = find_farm(&self.pool, farm_id);
        if kind != InternalApiFarmLookupResult::Found {
            return InternalFarmWeatherDataListResult::farm_not_found();
        }
        let farm = farm.expect("found");

        let Some(location_id) = farm.weather_location_id else {
            return InternalFarmWeatherDataListResult::weather_location_not_found();
        };

        let location = match load_weather_location(&self.pool, location_id) {
            Some(loc) => loc,
            None => return InternalFarmWeatherDataListResult::weather_location_not_found(),
        };

        let weather_data_rows = load_weather_data_rows(&self.pool, location_id);
        let count = weather_data_rows.len() as i64;

        let farm_summary = json!({
            "id": farm.id,
            "name": farm.name,
            "latitude": farm.latitude,
            "longitude": farm.longitude,
            "is_reference": farm.is_reference,
        });

        InternalFarmWeatherDataListResult::ok(InternalFarmWeatherDataListOutput {
            farm_summary,
            weather_location_summary: location,
            weather_data_rows,
            count,
        })
    }
}

fn farm_entity_progress(farm: &crate::shared::internal_api_farm_lookup::InternalApiFarmRow) -> i32 {
    let entity = FarmEntity {
        id: farm.id,
        name: farm.name.clone(),
        latitude: farm.latitude,
        longitude: farm.longitude,
        region: None,
        user_id: None,
        created_at: None,
        updated_at: None,
        is_reference: farm.is_reference,
        weather_data_status: farm.weather_data_status.clone(),
        weather_data_fetched_years: farm.weather_data_fetched_years,
        weather_data_total_years: farm.weather_data_total_years,
        weather_data_last_error: farm.weather_data_last_error.clone(),
        weather_location_id: farm.weather_location_id,
        last_broadcast_at: None,
    };
    entity.weather_data_progress()
}

fn weather_data_count_for_farm(pool: &SqlitePool, weather_location_id: Option<i64>) -> i32 {
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

fn load_weather_location(pool: &SqlitePool, location_id: i64) -> Option<Value> {
    pool.with_read(|conn| {
        conn.query_row(
            "SELECT latitude, longitude, elevation, timezone FROM weather_locations WHERE id = ?1",
            params![location_id],
            |row| {
                Ok(json!({
                    "latitude": row.get::<_, f64>(0)?,
                    "longitude": row.get::<_, f64>(1)?,
                    "elevation": row.get::<_, Option<f64>>(2)?,
                    "timezone": row.get::<_, Option<String>>(3)?,
                }))
            },
        )
    })
    .ok()
}

fn load_weather_data_rows(pool: &SqlitePool, location_id: i64) -> Vec<Value> {
    pool.with_read(|conn| {
        let mut stmt = conn.prepare(
            "SELECT date, temperature_max, temperature_min, temperature_mean, precipitation, \
             sunshine_hours, wind_speed, weather_code \
             FROM weather_data WHERE weather_location_id = ?1 ORDER BY date",
        )?;
        let rows = stmt.query_map(params![location_id], |row| {
            Ok(json!({
                "date": row.get::<_, String>(0)?,
                "temperature_max": row.get::<_, Option<f64>>(1)?,
                "temperature_min": row.get::<_, Option<f64>>(2)?,
                "temperature_mean": row.get::<_, Option<f64>>(3)?,
                "precipitation": row.get::<_, Option<f64>>(4)?,
                "sunshine_hours": row.get::<_, Option<f64>>(5)?,
                "wind_speed": row.get::<_, Option<f64>>(6)?,
                "weather_code": row.get::<_, Option<i64>>(7)?,
            }))
        })?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row?);
        }
        Ok(out)
    })
    .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicU64, Ordering};

    fn temp_pool_with_weather() -> (SqlitePool, PathBuf) {
        static COUNTER: AtomicU64 = AtomicU64::new(0);
        let n = COUNTER.fetch_add(1, Ordering::Relaxed);
        let path = std::env::temp_dir().join(format!("agrr_internal_weather_read_{n}.sqlite3"));
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
                CREATE TABLE weather_locations (
                    id INTEGER PRIMARY KEY,
                    latitude REAL NOT NULL,
                    longitude REAL NOT NULL,
                    elevation REAL,
                    timezone TEXT
                );
                CREATE TABLE weather_data (
                    id INTEGER PRIMARY KEY,
                    weather_location_id INTEGER NOT NULL,
                    date TEXT NOT NULL,
                    temperature_max REAL,
                    temperature_min REAL,
                    temperature_mean REAL,
                    precipitation REAL,
                    sunshine_hours REAL,
                    wind_speed REAL,
                    weather_code INTEGER
                );
                INSERT INTO weather_locations (id, latitude, longitude, elevation, timezone)
                VALUES (10, 35.1, 139.2, 40.0, 'Asia/Tokyo');
                INSERT INTO farms (id, name, latitude, longitude, is_reference,
                    weather_data_status, weather_data_fetched_years, weather_data_total_years,
                    weather_location_id)
                VALUES (1, 'Farm A', 35.0, 139.0, 0, 'fetching', 1, 5, 10);
                INSERT INTO weather_data (weather_location_id, date, temperature_max)
                VALUES (10, '2024-01-01', 10.5);",
            )
        })
        .expect("schema");
        (pool, path)
    }

    #[test]
    fn weather_status_snapshot_returns_progress_and_count() {
        let (pool, _path) = temp_pool_with_weather();
        let gw = InternalFarmWeatherReadSqliteGateway::new(pool);
        let result = gw.weather_status_snapshot("1");
        let InternalFarmWeatherStatusResult::Ok(dto) = result else {
            panic!("expected ok");
        };
        assert_eq!(dto.farm_id, 1);
        assert_eq!(dto.status, "fetching");
        assert_eq!(dto.fetched_blocks, 1);
        assert_eq!(dto.total_blocks, 5);
        assert_eq!(dto.weather_data_count, 1);
        assert_eq!(dto.progress, 20);
    }

    #[test]
    fn weather_data_list_snapshot_requires_weather_location() {
        let path = std::env::temp_dir().join("agrr_internal_weather_read_no_wl.sqlite3");
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
            INSERT INTO farms (id, name, latitude, longitude, is_reference)
            VALUES (2, 'No WL', 1.0, 2.0, 0);",
            )
        })
        .expect("schema");
        let gw = InternalFarmWeatherReadSqliteGateway::new(pool);
        let result = gw.weather_data_list_snapshot("2");
        assert!(matches!(
            result,
            InternalFarmWeatherDataListResult::WeatherLocationNotFound
        ));
    }
}
