//! Ruby: `Domain::CultivationPlan::Dtos::TaskScheduleAgriculturalTaskSnapshot`

use rust_decimal::Decimal;

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleAgriculturalTaskSnapshot {
    pub id: i64,
    pub name: String,
    pub description: Option<String>,
    pub task_type: Option<String>,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<Decimal>,
}
