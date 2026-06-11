//! Ruby: `Domain::CultivationPlan::Dtos::OptimizationPlanReadPlanCoreSnapshot`

use time::Date;

use crate::weather_data::dtos::PredictedWeatherMetadata;

/// Ruby: `Domain::CultivationPlan::Dtos::OptimizationPlanReadPlanCoreSnapshot`
#[derive(Debug, Clone)]
pub struct OptimizationPlanReadPlanCoreSnapshot {
    pub plan_id: i64,
    pub plan_type_private: bool,
    pub calculated_planning_start_date: Option<Date>,
    pub calculated_planning_end_date: Option<Date>,
    pub prediction_target_end_date: Option<Date>,
    pub plan_metadata: Option<PredictedWeatherMetadata>,
    pub total_area: Option<f64>,
    pub weather_location_present: bool,
}
