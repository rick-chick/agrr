//! Observed weather rows for field cultivation climate (SQLite `weather_data` table).

use agrr_domain::field_cultivation::dtos::ClimateObservedWeatherDatum;
use agrr_domain::field_cultivation::gateways::FieldCultivationWeatherDataGateway;
use rusqlite::{params, Connection};
use serde_json::json;
use time::Date;

pub struct FieldCultivationWeatherDataSqliteGateway {
    database_path: String,
}

impl FieldCultivationWeatherDataSqliteGateway {
    pub fn new(database_path: impl Into<String>) -> Self {
        Self {
            database_path: database_path.into(),
        }
    }

    fn open(&self) -> Result<Connection, rusqlite::Error> {
        Connection::open(&self.database_path)
    }
}

impl FieldCultivationWeatherDataGateway for FieldCultivationWeatherDataSqliteGateway {
    fn weather_data_for_period(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Vec<ClimateObservedWeatherDatum> {
        let Ok(conn) = self.open() else {
            return vec![];
        };
        let start = start_date.to_string();
        let end = end_date.to_string();
        let mut stmt = match conn.prepare(
            "SELECT date, temperature_max, temperature_min, temperature_mean, \
             precipitation, sunshine_hours, wind_speed, weather_code \
             FROM weather_data \
             WHERE weather_location_id = ?1 AND date >= ?2 AND date <= ?3 \
             AND temperature_max IS NOT NULL AND temperature_min IS NOT NULL \
             ORDER BY date",
        ) {
            Ok(s) => s,
            Err(_) => return vec![],
        };
        let rows = match stmt.query_map(params![weather_location_id, start, end], |row| {
            let date_str: String = row.get(0)?;
            let format = time::format_description::parse("[year]-[month]-[day]")
                .map_err(|_| rusqlite::Error::InvalidQuery)?;
            let date = time::Date::parse(&date_str, &format)
                .map_err(|_| rusqlite::Error::InvalidQuery)?;
            Ok(ClimateObservedWeatherDatum {
                date,
                temperature_max: row.get(1)?,
                temperature_min: row.get(2)?,
                temperature_mean: row.get(3)?,
                precipitation: row.get(4)?,
                sunshine_hours: row.get(5)?,
                wind_speed: row.get(6)?,
                weather_code: row.get(7)?,
            })
        }) {
            Ok(r) => r,
            Err(_) => return vec![],
        };
        rows.filter_map(|r| r.ok()).collect()
    }

    fn format_for_agrr(
        &self,
        weather_data_dtos: &[ClimateObservedWeatherDatum],
        weather_location: &serde_json::Value,
    ) -> serde_json::Value {
        let data: Vec<serde_json::Value> = weather_data_dtos
            .iter()
            .map(|d| {
                json!({
                    "time": d.date.to_string(),
                    "temperature_2m_max": d.temperature_max,
                    "temperature_2m_min": d.temperature_min,
                    "temperature_2m_mean": d.temperature_mean,
                    "precipitation_sum": d.precipitation,
                    "sunshine_duration": d.sunshine_hours,
                    "wind_speed_10m": d.wind_speed,
                    "weather_code": d.weather_code,
                })
            })
            .collect();
        json!({
            "latitude": weather_location.get("latitude"),
            "longitude": weather_location.get("longitude"),
            "elevation": weather_location.get("elevation"),
            "timezone": weather_location.get("timezone").and_then(|v| v.as_str()).unwrap_or("Asia/Tokyo"),
            "data": data,
        })
    }
}
