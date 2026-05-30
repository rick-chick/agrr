//! Ruby: `Domain::CultivationPlan::Dtos::OptimizationPlanReadPlanCoreSnapshot`

use serde_json::Value;
use time::Date;

/// Ruby: `Domain::CultivationPlan::Dtos::OptimizationPlanReadPlanCoreSnapshot`
#[derive(Debug, Clone)]
pub struct OptimizationPlanReadPlanCoreSnapshot {
    pub plan_id: i64,
    pub plan_type_private: bool,
    pub calculated_planning_start_date: Option<Date>,
    pub calculated_planning_end_date: Option<Date>,
    pub prediction_target_end_date: Option<Date>,
    pub predicted_weather_data: Option<Value>,
    pub total_area: Option<f64>,
    pub weather_location_present: bool,
}
