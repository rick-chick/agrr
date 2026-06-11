use serde_json::Value;
use time::Date;

use crate::weather_data::dtos::PredictedWeatherMetadata;

#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationClimateContextSnapshot {
    pub field_cultivation_id: i64,
    pub field_name: String,
    pub crop_name: String,
    pub start_date: Date,
    pub completion_date: Date,
    pub farm_id: i64,
    pub farm_name: String,
    pub farm_latitude: f64,
    pub farm_longitude: f64,
    pub plan_id: i64,
    pub plan_type_public: bool,
    pub plan_predicted_weather_present: bool,
    pub prediction_target_end_date: Option<Date>,
    pub calculated_planning_end_date: Option<Date>,
    pub plan_metadata: Option<PredictedWeatherMetadata>,
    pub crop_id: i64,
    pub base_temperature: f64,
    pub optimal_temperature_range: Option<Value>,
    pub stages: Vec<Value>,
}
