//! Ruby: `Domain::CultivationPlan::Dtos::OptimizationPlanSnapshot`

use serde_json::Value;
use time::Date;

use crate::weather_data::dtos::{FarmWeatherPrediction, WeatherLocation};

/// Ruby: `Domain::CultivationPlan::Dtos::OptimizationPlanSnapshot`
#[derive(Debug, Clone)]
pub struct OptimizationPlanSnapshot {
    pub plan_id: i64,
    pub plan_type_private: bool,
    pub calculated_planning_start_date: Option<Date>,
    pub calculated_planning_end_date: Option<Date>,
    pub prediction_target_end_date: Option<Date>,
    pub predicted_weather_data: Option<Value>,
    pub total_area: Option<f64>,
    pub weather_location_present: bool,
    pub weather_location_input: Option<WeatherLocation>,
    pub farm_weather_input: Option<FarmWeatherPrediction>,
}

impl OptimizationPlanSnapshot {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        plan_id: i64,
        plan_type_private: bool,
        calculated_planning_start_date: Option<Date>,
        calculated_planning_end_date: Option<Date>,
        prediction_target_end_date: Option<Date>,
        predicted_weather_data: Option<Value>,
        total_area: Option<f64>,
        weather_location_present: bool,
        weather_location_input: Option<WeatherLocation>,
        farm_weather_input: Option<FarmWeatherPrediction>,
    ) -> Self {
        Self {
            plan_id,
            plan_type_private,
            calculated_planning_start_date,
            calculated_planning_end_date,
            prediction_target_end_date,
            predicted_weather_data,
            total_area,
            weather_location_present,
            weather_location_input,
            farm_weather_input,
        }
    }
}
