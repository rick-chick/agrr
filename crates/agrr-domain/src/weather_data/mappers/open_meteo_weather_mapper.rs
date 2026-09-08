//! Ruby: `Domain::WeatherData::Mappers::OpenMeteoWeatherMapper`

use serde_json::{json, Value};

use crate::weather_data::dtos::WeatherData;
use crate::weather_data::helpers::parse_iso_date;

/// Ruby: `Domain::WeatherData::Mappers::OpenMeteoWeatherMapper`
pub struct OpenMeteoWeatherMapper;

impl OpenMeteoWeatherMapper {
    pub fn from_agrr_daily_json(daily: &Value) -> Option<WeatherData> {
        let date_str = daily.get("time")?.as_str()?;
        let date = parse_iso_date(date_str)?;
        Some(WeatherData::new(
            date,
            daily.get("temperature_2m_max").and_then(|v| v.as_f64()),
            daily.get("temperature_2m_min").and_then(|v| v.as_f64()),
            daily.get("temperature_2m_mean").and_then(|v| v.as_f64()),
            daily.get("precipitation_sum").and_then(|v| v.as_f64()),
            daily.get("sunshine_hours").and_then(|v| v.as_f64()),
            daily.get("wind_speed_10m").and_then(|v| v.as_f64()),
            daily
                .get("weather_code")
                .and_then(|v| v.as_i64())
                .map(|v| v as i32),
        ))
    }

    pub fn format_for_agrr(
        weather_data_dtos: &[WeatherData],
        latitude: f64,
        longitude: f64,
        elevation: Option<f64>,
        timezone: &str,
    ) -> Value {
        let data: Vec<Value> = weather_data_dtos
            .iter()
            .map(|dto| {
                json!({
                    "time": dto.date.to_string(),
                    "temperature_2m_max": dto.temperature_max,
                    "temperature_2m_min": dto.temperature_min,
                    "temperature_2m_mean": dto.temperature_mean,
                    "precipitation_sum": dto.precipitation,
                    "sunshine_duration": dto.sunshine_hours.map(|h| h * 3600.0).unwrap_or(0.0),
                    "wind_speed_10m_max": dto.wind_speed,
                    "weather_code": dto.weather_code,
                })
            })
            .collect();

        json!({
            "latitude": latitude,
            "longitude": longitude,
            "elevation": elevation.unwrap_or(0.0),
            "timezone": timezone,
            "data": data,
        })
    }
}

#[cfg(test)]
mod mappers_open_meteo_weather_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/mappers_open_meteo_weather_mapper_test.rs"));
}
