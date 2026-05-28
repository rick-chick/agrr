//! Ruby: `Domain::WeatherData::Dtos::FarmWeatherPrediction`

use serde_json::Value;

use crate::weather_data::helpers::copy_and_deep_freeze;

/// Ruby: `Domain::WeatherData::Dtos::FarmWeatherPrediction`
#[derive(Debug, Clone)]
pub struct FarmWeatherPrediction {
    pub id: i64,
    pub weather_location_id: i64,
    predicted_weather_data: Option<Value>,
}

impl FarmWeatherPrediction {
    pub fn new(
        id: i64,
        weather_location_id: i64,
        predicted_weather_data: Option<Value>,
    ) -> Self {
        Self {
            id,
            weather_location_id,
            predicted_weather_data: copy_and_deep_freeze(predicted_weather_data),
        }
    }

    pub fn predicted_weather_data(&self) -> Option<&Value> {
        self.predicted_weather_data.as_ref()
    }
}
