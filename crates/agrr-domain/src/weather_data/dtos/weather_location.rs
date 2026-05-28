//! Ruby: `Domain::WeatherData::Dtos::WeatherLocation`

use serde_json::Value;

use crate::weather_data::helpers::copy_and_deep_freeze;

/// Ruby: `Domain::WeatherData::Dtos::WeatherLocation`
#[derive(Debug, Clone)]
pub struct WeatherLocation {
    pub id: i64,
    pub latitude: f64,
    pub longitude: f64,
    pub elevation: Option<f64>,
    pub timezone: Option<String>,
    predicted_weather_data: Option<Value>,
}

impl WeatherLocation {
    pub fn new(
        id: i64,
        latitude: f64,
        longitude: f64,
        elevation: Option<f64>,
        timezone: Option<String>,
        predicted_weather_data: Option<Value>,
    ) -> Self {
        Self {
            id,
            latitude,
            longitude,
            elevation,
            timezone,
            predicted_weather_data: copy_and_deep_freeze(predicted_weather_data),
        }
    }

    pub fn predicted_weather_data(&self) -> Option<&Value> {
        self.predicted_weather_data.as_ref()
    }
}
