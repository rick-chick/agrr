//! Ruby: `Domain::WeatherData::Mappers::OpenMeteoWeatherMapper`

use serde_json::{json, Value};

use crate::weather_data::dtos::WeatherData;

/// Ruby: `Domain::WeatherData::Mappers::OpenMeteoWeatherMapper`
pub struct OpenMeteoWeatherMapper;

impl OpenMeteoWeatherMapper {
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
mod tests {
    use super::*;
    use time::{Date, Month};

    #[test]
    fn format_for_agrr_builds_agrr_hash() {
        let dto = WeatherData::new(
            Date::from_calendar_date(2023, Month::January, 1).expect("valid"),
            Some(10.0),
            None,
            None,
            None,
            None,
            None,
            None,
        );
        let result = OpenMeteoWeatherMapper::format_for_agrr(&[dto], 35.0, 139.0, None, "UTC");
        assert_eq!(result["latitude"], 35.0);
        assert_eq!(result["longitude"], 139.0);
        assert_eq!(result["elevation"], 0.0);
        assert_eq!(result["timezone"], "UTC");
        assert_eq!(result["data"].as_array().map(|a| a.len()), Some(1));
    }
}
