//! Ruby: `Domain::CultivationPlan::Mappers::OptimizationPlanSnapshotMapper`

use serde_json::Value;
use time::Date;

use crate::cultivation_plan::dtos::OptimizationPlanSnapshot;
use crate::weather_data::dtos::{FarmWeatherPrediction, WeatherLocation};

pub fn to_snapshot(
    plan_id: i64,
    plan_type_private: bool,
    calculated_planning_start_date: Option<Date>,
    calculated_planning_end_date: Option<Date>,
    prediction_target_end_date: Option<Date>,
    predicted_weather_data: Option<Value>,
    total_area: Option<f64>,
    weather_location_present: bool,
    weather_location: Option<WeatherLocation>,
    farm_weather: Option<FarmWeatherPrediction>,
) -> OptimizationPlanSnapshot {
    OptimizationPlanSnapshot::new(
        plan_id,
        plan_type_private,
        calculated_planning_start_date,
        calculated_planning_end_date,
        prediction_target_end_date,
        predicted_weather_data,
        total_area,
        weather_location_present,
        weather_location,
        farm_weather,
    )
}

#[cfg(test)]
mod mappers_optimization_plan_snapshot_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/mappers_optimization_plan_snapshot_mapper_test.rs"));
}
