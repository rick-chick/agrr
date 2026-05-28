//! Ruby: `Domain::WeatherData::Dtos::CultivationPlanWeather`

use serde_json::Value;
use time::Date;

use crate::weather_data::helpers::copy_and_deep_freeze;

/// Ruby: `Domain::WeatherData::Dtos::CultivationPlanWeather`
#[derive(Debug, Clone)]
pub struct CultivationPlanWeather {
    pub id: i64,
    pub prediction_target_end_date: Option<Date>,
    pub calculated_planning_end_date: Option<Date>,
    predicted_weather_data: Option<Value>,
}

impl CultivationPlanWeather {
    pub fn new(
        id: i64,
        prediction_target_end_date: Option<Date>,
        calculated_planning_end_date: Option<Date>,
        predicted_weather_data: Option<Value>,
    ) -> Self {
        Self {
            id,
            prediction_target_end_date,
            calculated_planning_end_date,
            predicted_weather_data: copy_and_deep_freeze(predicted_weather_data),
        }
    }

    pub fn predicted_weather_data(&self) -> Option<&Value> {
        self.predicted_weather_data.as_ref()
    }
}
