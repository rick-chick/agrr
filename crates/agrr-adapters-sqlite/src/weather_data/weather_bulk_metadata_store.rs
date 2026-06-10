//! Persistence for [`WeatherBulkMetadata`] on `weather_locations`.

use rusqlite::params;

use crate::pool::SqlitePool;
use crate::weather_data::weather_bulk_metadata::{parse_date, WeatherBulkMetadata};

pub(crate) struct WeatherBulkMetadataStore {
    pool: SqlitePool,
}

impl WeatherBulkMetadataStore {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    pub fn load(&self, weather_location_id: i64) -> Result<Option<WeatherBulkMetadata>, String> {
        self.pool
            .with_read(|conn| {
                let row: Result<(Option<String>, Option<String>, Option<String>), _> = conn
                    .query_row(
                        "SELECT bulk_earliest_date, bulk_latest_date, bulk_year_stats \
                         FROM weather_locations WHERE id = ?1",
                        params![weather_location_id],
                        |row| Ok((row.get(0)?, row.get(1)?, row.get(2)?)),
                    );
                let Ok((earliest, latest, stats_json)) = row else {
                    return Ok(None);
                };
                let Some(stats_json) = stats_json else {
                    if earliest.is_none() && latest.is_none() {
                        return Ok(None);
                    }
                    return Ok(Some(WeatherBulkMetadata {
                        earliest_date: earliest,
                        latest_date: latest,
                        years: Default::default(),
                    }));
                };
                let mut metadata: WeatherBulkMetadata = serde_json::from_str(&stats_json)
                    .map_err(|e| rusqlite::Error::ToSqlConversionFailure(Box::new(e)))?;
                if metadata.earliest_date.is_none() {
                    metadata.earliest_date = earliest;
                }
                if metadata.latest_date.is_none() {
                    metadata.latest_date = latest;
                }
                Ok(Some(metadata))
            })
            .map_err(|e| e.to_string())
    }

    pub fn save(
        &self,
        weather_location_id: i64,
        metadata: &WeatherBulkMetadata,
    ) -> Result<(), String> {
        let stats_json = serde_json::to_string(metadata).map_err(|e| e.to_string())?;
        self.pool
            .with_write(|conn| {
                conn.execute(
                    "UPDATE weather_locations \
                     SET bulk_earliest_date = ?1, bulk_latest_date = ?2, bulk_year_stats = ?3, \
                         updated_at = datetime('now') \
                     WHERE id = ?4",
                    params![
                        metadata.earliest_date,
                        metadata.latest_date,
                        stats_json,
                        weather_location_id
                    ],
                )?;
                Ok(())
            })
            .map_err(|e| e.to_string())
    }

    pub fn earliest_date(
        &self,
        weather_location_id: i64,
    ) -> Result<Option<time::Date>, String> {
        Ok(self
            .load(weather_location_id)?
            .and_then(|m| m.earliest_date)
            .and_then(|s| parse_date(&s)))
    }

    pub fn latest_date(&self, weather_location_id: i64) -> Result<Option<time::Date>, String> {
        Ok(self
            .load(weather_location_id)?
            .and_then(|m| m.latest_date)
            .and_then(|s| parse_date(&s)))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::weather_data::weather_bulk_metadata::{WeatherBulkMetadata, WeatherYearStats};
    use std::collections::BTreeMap;

    fn test_pool_with_location() -> (SqlitePool, i64) {
        let path = std::env::temp_dir().join(format!(
            "agrr_bulk_meta_store_{}_{}.sqlite3",
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
                    elevation REAL,
                    timezone TEXT,
                    created_at TEXT NOT NULL DEFAULT '1970-01-01',
                    updated_at TEXT NOT NULL DEFAULT '1970-01-01',
                    predicted_weather_data TEXT,
                    bulk_earliest_date TEXT,
                    bulk_latest_date TEXT,
                    bulk_year_stats TEXT
                );",
            )?;
            conn.execute(
                "INSERT INTO weather_locations (id, latitude, longitude) VALUES (1, 35.0, 139.0)",
                [],
            )?;
            Ok(())
        })
        .expect("schema");
        (pool, 1)
    }

    #[test]
    fn save_and_load_round_trip() {
        let (pool, location_id) = test_pool_with_location();
        let store = WeatherBulkMetadataStore::new(pool);
        let metadata = WeatherBulkMetadata {
            earliest_date: Some("2024-01-01".into()),
            latest_date: Some("2024-01-02".into()),
            years: BTreeMap::from([(
                "2024".into(),
                WeatherYearStats {
                    count: 2,
                    historical_count: 2,
                    first_date: "2024-01-01".into(),
                    last_date: "2024-01-02".into(),
                },
            )]),
        };
        store.save(location_id, &metadata).expect("save");
        let loaded = store.load(location_id).expect("load").expect("some");
        assert_eq!(loaded, metadata);
    }

    #[test]
    fn latest_date_reads_bulk_latest_date_column() {
        let (pool, location_id) = test_pool_with_location();
        let store = WeatherBulkMetadataStore::new(pool);
        let metadata = WeatherBulkMetadata {
            earliest_date: Some("2024-01-01".into()),
            latest_date: Some("2024-01-02".into()),
            years: BTreeMap::from([(
                "2024".into(),
                WeatherYearStats {
                    count: 2,
                    historical_count: 2,
                    first_date: "2024-01-01".into(),
                    last_date: "2024-01-02".into(),
                },
            )]),
        };
        store.save(location_id, &metadata).expect("save");
        assert_eq!(
            store.latest_date(location_id).expect("latest"),
            Some(time::Date::from_calendar_date(2024, time::Month::January, 2).unwrap())
        );
    }
}
