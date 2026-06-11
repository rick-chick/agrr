//! Ruby: `Domain::CultivationPlan::Dtos::OptimizationPlanSnapshot`

use time::Date;

use crate::weather_data::dtos::{PredictedWeatherMetadata, WeatherLocation};

/// Ruby: `Domain::CultivationPlan::Dtos::OptimizationPlanSnapshot`
#[derive(Debug, Clone)]
pub struct OptimizationPlanSnapshot {
    pub plan_id: i64,
    pub plan_type_private: bool,
    pub calculated_planning_start_date: Option<Date>,
    pub calculated_planning_end_date: Option<Date>,
    pub prediction_target_end_date: Option<Date>,
    pub plan_metadata: Option<PredictedWeatherMetadata>,
    pub total_area: Option<f64>,
    pub weather_location_present: bool,
    pub weather_location_input: Option<WeatherLocation>,
}

impl OptimizationPlanSnapshot {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        plan_id: i64,
        plan_type_private: bool,
        calculated_planning_start_date: Option<Date>,
        calculated_planning_end_date: Option<Date>,
        prediction_target_end_date: Option<Date>,
        plan_metadata: Option<PredictedWeatherMetadata>,
        total_area: Option<f64>,
        weather_location_present: bool,
        weather_location_input: Option<WeatherLocation>,
    ) -> Self {
        Self {
            plan_id,
            plan_type_private,
            calculated_planning_start_date,
            calculated_planning_end_date,
            prediction_target_end_date,
            plan_metadata,
            total_area,
            weather_location_present,
            weather_location_input,
        }
    }
}
