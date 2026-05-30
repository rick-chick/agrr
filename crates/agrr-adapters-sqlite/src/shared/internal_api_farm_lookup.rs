//! Ruby: `Adapters::Shared::InternalApiFarmLookup`

use crate::pool::SqlitePool;
use rusqlite::{params, OptionalExtension};

/// Farm row for internal API endpoints (weather status / data / fetch start).
#[derive(Debug, Clone, PartialEq)]
pub struct InternalApiFarmRow {
    pub id: i64,
    pub name: String,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
    pub is_reference: bool,
    pub weather_data_status: Option<String>,
    pub weather_data_fetched_years: Option<i32>,
    pub weather_data_total_years: Option<i32>,
    pub weather_data_last_error: Option<String>,
    pub weather_location_id: Option<i64>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum InternalApiFarmLookupResult {
    NotFound,
    Found,
}

impl InternalApiFarmLookupResult {
    pub fn is_found(self) -> bool {
        matches!(self, Self::Found)
    }
}

/// Parse `farm_id` param and load farm when present (positive integer id).
pub fn find_farm(pool: &SqlitePool, farm_id_param: &str) -> (InternalApiFarmLookupResult, Option<InternalApiFarmRow>) {
    let id = parse_farm_id(farm_id_param);
    let Some(farm_id) = id else {
        return (InternalApiFarmLookupResult::NotFound, None);
    };

    let row = pool
        .with_read(|conn| {
            conn.query_row(
                "SELECT id, name, latitude, longitude, is_reference, weather_data_status, \
                 weather_data_fetched_years, weather_data_total_years, weather_data_last_error, \
                 weather_location_id \
                 FROM farms WHERE id = ?1",
                params![farm_id],
                |row| {
                    let is_reference: i64 = row.get(4)?;
                    Ok(InternalApiFarmRow {
                        id: row.get(0)?,
                        name: row.get(1)?,
                        latitude: row.get(2)?,
                        longitude: row.get(3)?,
                        is_reference: is_reference != 0,
                        weather_data_status: row.get(5)?,
                        weather_data_fetched_years: row.get(6)?,
                        weather_data_total_years: row.get(7)?,
                        weather_data_last_error: row.get(8)?,
                        weather_location_id: row.get(9)?,
                    })
                },
            )
            .optional()
        })
        .ok()
        .flatten();

    match row {
        Some(farm) => (InternalApiFarmLookupResult::Found, Some(farm)),
        None => (InternalApiFarmLookupResult::NotFound, None),
    }
}

fn parse_farm_id(farm_id_param: &str) -> Option<i64> {
    let trimmed = farm_id_param.trim();
    if trimmed.is_empty() {
        return None;
    }
    let id: i64 = trimmed.parse().ok()?;
    if id > 0 {
        Some(id)
    } else {
        None
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicU64, Ordering};

    fn temp_pool() -> (SqlitePool, PathBuf) {
        static COUNTER: AtomicU64 = AtomicU64::new(0);
        let n = COUNTER.fetch_add(1, Ordering::Relaxed);
        let path = std::env::temp_dir().join(format!("agrr_internal_farm_lookup_{n}.sqlite3"));
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
            INSERT INTO farms (id, name, latitude, longitude, is_reference,
                weather_data_status, weather_data_fetched_years, weather_data_total_years)
            VALUES (7, 'Test Farm', 35.0, 139.0, 0, 'completed', 2, 5);",
            )
        })
        .expect("schema");
        (pool, path)
    }

    #[test]
    fn find_farm_returns_not_found_for_invalid_id() {
        let (pool, _path) = temp_pool();
        let (kind, row) = find_farm(&pool, "0");
        assert_eq!(kind, InternalApiFarmLookupResult::NotFound);
        assert!(row.is_none());
    }

    #[test]
    fn find_farm_returns_row_for_existing_farm() {
        let (pool, _path) = temp_pool();
        let (kind, row) = find_farm(&pool, "7");
        assert_eq!(kind, InternalApiFarmLookupResult::Found);
        let farm = row.expect("farm");
        assert_eq!(farm.id, 7);
        assert_eq!(farm.name, "Test Farm");
        assert_eq!(farm.weather_data_status.as_deref(), Some("completed"));
    }
}
