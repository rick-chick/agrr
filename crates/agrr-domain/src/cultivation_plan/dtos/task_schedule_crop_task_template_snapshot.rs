//! Ruby: `Domain::CultivationPlan::Dtos::TaskScheduleCropTaskTemplateSnapshot`

use rust_decimal::Decimal;

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleCropTaskTemplateSnapshot {
    pub id: i64,
    pub crop_id: i64,
    pub name: String,
    pub description: Option<String>,
    pub task_type: Option<String>,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<Decimal>,
    pub agricultural_task_id: i64,
}
