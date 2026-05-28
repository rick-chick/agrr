use serde_json::Value;
use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationClimateSourceSnapshot {
    pub field_cultivation_id: i64,
    pub field_name: String,
    pub crop_name: String,
    pub start_date: Option<Date>,
    pub completion_date: Option<Date>,
    pub farm_id: i64,
    pub farm_name: String,
    pub farm_latitude: f64,
    pub farm_longitude: f64,
    pub weather_location_id: Option<i64>,
    pub weather_location_timezone: Option<String>,
    pub plan_id: i64,
    pub plan_type_public: bool,
    pub prediction_target_end_date: Option<Date>,
    pub calculated_planning_end_date: Option<Date>,
    pub predicted_weather_data: Option<Value>,
    pub plan_crop_crop_id: Option<i64>,
}
