use serde_json::Value;
use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationSyncDesiredRow {
    pub field_cultivation_id: Option<i64>,
    pub cultivation_plan_field_id: i64,
    pub cultivation_plan_crop_id: i64,
    pub start_date: Date,
    pub completion_date: Date,
    pub cultivation_days: i32,
    pub area: Option<f64>,
    pub estimated_cost: Option<f64>,
    pub optimization_result: Value,
}
