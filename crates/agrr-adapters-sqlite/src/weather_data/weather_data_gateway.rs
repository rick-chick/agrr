//! Ruby: `Adapters::WeatherData::Gateways::WeatherDataActiveRecordGateway`

use crate::pool::SqlitePool;
use agrr_domain::weather_data::dtos::WeatherData;
use agrr_domain::weather_data::gateways::{
    WeatherDataGateway, WeatherDataStorageError, WeatherLocationRecord,
};
use rusqlite::{params, OptionalExtension};
use serde_json::Value;
use time::Date;

pub struct WeatherDataSqliteGateway {
    pool: SqlitePool,
}

impl WeatherDataSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

fn parse_date(s: &str) -> Option<Date> {
    Date::parse(s.trim(), &time::format_description::parse("[year]-[month]-[day]").ok()?).ok()
}

fn date_str(d: Date) -> String {
    d.to_string()
}

fn storage_err(e: rusqlite::Error) -> WeatherDataStorageError {
    WeatherDataStorageError::new(e.to_string())
}

impl WeatherDataGateway for WeatherDataSqliteGateway {
    fn weather_data_for_period(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<Vec<WeatherData>, WeatherDataStorageError> {
        self.pool
            .with_read(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT date, temperature_max, temperature_min, temperature_mean, \
                     precipitation, sunshine_hours, wind_speed, weather_code \
                     FROM weather_data \
                     WHERE weather_location_id = ?1 AND date >= ?2 AND date <= ?3 \
                     ORDER BY date",
                )?;
                let rows = stmt.query_map(
                    params![
                        weather_location_id,
                        date_str(start_date),
                        date_str(end_date)
                    ],
                    |row| {
                        Ok(WeatherData::new(
                            parse_date(&row.get::<_, String>(0)?).unwrap_or(start_date),
                            row.get(1)?,
                            row.get(2)?,
                            row.get(3)?,
                            row.get(4)?,
                            row.get(5)?,
                            row.get(6)?,
                            row.get(7)?,
                        ))
                    },
                )?;
                let mut out = Vec::new();
                for row in rows {
                    out.push(row?);
                }
                Ok(out)
            })
            .map_err(storage_err)
    }

    fn weather_data_count(
        &self,
        weather_location_id: i64,
        start_date: Option<Date>,
        end_date: Option<Date>,
    ) -> Result<i64, WeatherDataStorageError> {
        self.pool
            .with_read(|conn| {
                let (sql, start, end) = match (start_date, end_date) {
                    (Some(s), Some(e)) => (
                        "SELECT COUNT(*) FROM weather_data WHERE weather_location_id = ?1 AND date >= ?2 AND date <= ?3",
                        Some(date_str(s)),
                        Some(date_str(e)),
                    ),
                    (Some(s), None) => (
                        "SELECT COUNT(*) FROM weather_data WHERE weather_location_id = ?1 AND date >= ?2",
                        Some(date_str(s)),
                        None,
                    ),
                    (None, Some(e)) => (
                        "SELECT COUNT(*) FROM weather_data WHERE weather_location_id = ?1 AND date <= ?2",
                        None,
                        Some(date_str(e)),
                    ),
                    (None, None) => (
                        "SELECT COUNT(*) FROM weather_data WHERE weather_location_id = ?1",
                        None,
                        None,
                    ),
                };
                match (start, end) {
                    (Some(s), Some(e)) => conn.query_row(sql, params![weather_location_id, s, e], |r| r.get(0)),
                    (Some(s), None) => conn.query_row(sql, params![weather_location_id, s], |r| r.get(0)),
                    (None, Some(e)) => conn.query_row(sql, params![weather_location_id, e], |r| r.get(0)),
                    (None, None) => conn.query_row(sql, params![weather_location_id], |r| r.get(0)),
                }
            })
            .map_err(storage_err)
    }

    fn historical_data_count(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<i64, WeatherDataStorageError> {
        self.pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT COUNT(*) FROM weather_data \
                     WHERE weather_location_id = ?1 AND date >= ?2 AND date <= ?3 \
                     AND temperature_max IS NOT NULL AND temperature_min IS NOT NULL",
                    params![
                        weather_location_id,
                        date_str(start_date),
                        date_str(end_date)
                    ],
                    |row| row.get(0),
                )
            })
            .map_err(storage_err)
    }

    fn earliest_date(
        &self,
        weather_location_id: i64,
    ) -> Result<Option<Date>, WeatherDataStorageError> {
        self.pool
            .with_read(|conn| {
                let s: Option<String> = conn.query_row(
                    "SELECT MIN(date) FROM weather_data WHERE weather_location_id = ?1",
                    params![weather_location_id],
                    |row| row.get(0),
                )?;
                Ok(s.and_then(|d| parse_date(&d)))
            })
            .map_err(storage_err)
    }

    fn latest_date(
        &self,
        weather_location_id: i64,
    ) -> Result<Option<Date>, WeatherDataStorageError> {
        self.pool
            .with_read(|conn| {
                let s: Option<String> = conn.query_row(
                    "SELECT MAX(date) FROM weather_data WHERE weather_location_id = ?1",
                    params![weather_location_id],
                    |row| row.get(0),
                )?;
                Ok(s.and_then(|d| parse_date(&d)))
            })
            .map_err(storage_err)
    }

    fn upsert_weather_data(
        &self,
        weather_data_dtos: &[WeatherData],
        weather_location_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if weather_data_dtos.is_empty() {
            return Ok(());
        }
        self.pool.with_write(|conn| {
            let mut stmt = conn.prepare(
                "INSERT INTO weather_data \
                 (weather_location_id, date, temperature_max, temperature_min, temperature_mean, \
                  precipitation, sunshine_hours, wind_speed, weather_code, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, datetime('now'), datetime('now')) \
                 ON CONFLICT(weather_location_id, date) DO UPDATE SET \
                 temperature_max = excluded.temperature_max, \
                 temperature_min = excluded.temperature_min, \
                 temperature_mean = excluded.temperature_mean, \
                 precipitation = excluded.precipitation, \
                 sunshine_hours = excluded.sunshine_hours, \
                 wind_speed = excluded.wind_speed, \
                 weather_code = excluded.weather_code, \
                 updated_at = datetime('now')",
            )?;
            for dto in weather_data_dtos {
                stmt.execute(params![
                    weather_location_id,
                    date_str(dto.date),
                    dto.temperature_max,
                    dto.temperature_min,
                    dto.temperature_mean,
                    dto.precipitation,
                    dto.sunshine_hours,
                    dto.wind_speed,
                    dto.weather_code,
                ])?;
            }
            Ok(())
        })?;
        Ok(())
    }

    fn find_by_coordinates(
        &self,
        latitude: f64,
        longitude: f64,
    ) -> Option<WeatherLocationRecord> {
        self.pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT id FROM weather_locations \
                     WHERE ABS(latitude - ?1) < 0.0001 AND ABS(longitude - ?2) < 0.0001 \
                     LIMIT 1",
                    params![latitude, longitude],
                    |row| Ok(WeatherLocationRecord { id: row.get(0)? }),
                )
                .optional()
            })
            .ok()
            .flatten()
    }

    fn find_or_create_weather_location(
        &self,
        latitude: f64,
        longitude: f64,
        elevation: Option<f64>,
        timezone: Option<&str>,
    ) -> Result<WeatherLocationRecord, Box<dyn std::error::Error + Send + Sync>> {
        if let Some(existing) = self.find_by_coordinates(latitude, longitude) {
            return Ok(existing);
        }
        self.pool.with_write_box(|conn| {
            conn.execute(
                "INSERT INTO weather_locations (latitude, longitude, elevation, timezone, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, datetime('now'), datetime('now'))",
                params![latitude, longitude, elevation, timezone],
            )?;
            let id = conn.last_insert_rowid();
            Ok(WeatherLocationRecord { id })
        })
    }

    fn update_predicted_weather_data(
        &self,
        weather_location_id: i64,
        payload: &Value,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let json = serde_json::to_string(payload)?;
        self.pool.with_write(|conn| {
            conn.execute(
                "UPDATE weather_locations SET predicted_weather_data = ?1, updated_at = datetime('now') WHERE id = ?2",
                params![json, weather_location_id],
            )?;
            Ok(())
        })?;
        Ok(())
    }
}
