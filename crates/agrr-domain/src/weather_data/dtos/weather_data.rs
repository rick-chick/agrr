//! Ruby: `Domain::WeatherData::Dtos::WeatherData`

use time::Date;

/// Ruby: `Domain::WeatherData::Dtos::WeatherData`
#[derive(Debug, Clone, PartialEq)]
pub struct WeatherData {
    pub date: Date,
    pub temperature_max: Option<f64>,
    pub temperature_min: Option<f64>,
    pub temperature_mean: Option<f64>,
    pub precipitation: Option<f64>,
    pub sunshine_hours: Option<f64>,
    pub wind_speed: Option<f64>,
    pub weather_code: Option<i32>,
}

impl WeatherData {
    pub fn new(
        date: Date,
        temperature_max: Option<f64>,
        temperature_min: Option<f64>,
        temperature_mean: Option<f64>,
        precipitation: Option<f64>,
        sunshine_hours: Option<f64>,
        wind_speed: Option<f64>,
        weather_code: Option<i32>,
    ) -> Self {
        Self {
            date,
            temperature_max,
            temperature_min,
            temperature_mean,
            precipitation,
            sunshine_hours,
            wind_speed,
            weather_code,
        }
    }
}
