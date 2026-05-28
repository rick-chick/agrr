//! Ruby: `Domain::CultivationPlan::Gateways::AdjustWeatherPredictionGateway`

use crate::weather_data::dtos::{FarmWeatherPrediction, WeatherLocation};
use crate::weather_data::dtos::CultivationPlanWeather;
use serde_json::Value;
use time::Date;

/// Prediction service: `get_existing_prediction` / `predict_for_cultivation_plan`.
pub trait WeatherPredictionService: Send + Sync {
    fn get_existing_prediction(
        &self,
        target_end_date: Date,
        cultivation_plan_weather: &CultivationPlanWeather,
    ) -> Option<Value>;

    fn predict_for_cultivation_plan(
        &self,
        cultivation_plan_weather: &CultivationPlanWeather,
        target_end_date: Option<Date>,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;
}

pub trait AdjustWeatherPredictionGateway: Send + Sync {
    fn prediction_service(
        &self,
        weather_location: &WeatherLocation,
        farm: Option<&FarmWeatherPrediction>,
    ) -> Result<Box<dyn WeatherPredictionService>, Box<dyn std::error::Error + Send + Sync>>;
}
