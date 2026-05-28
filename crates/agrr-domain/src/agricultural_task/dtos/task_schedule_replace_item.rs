use rust_decimal::Decimal;
use time::Date;

/// Item attributes passed to task schedule gateway replace.
#[derive(Debug, Clone)]
pub struct TaskScheduleReplaceItem {
    pub task_type: String,
    pub agricultural_task_id: Option<i64>,
    pub name: String,
    pub description: Option<String>,
    pub stage_name: Option<String>,
    pub stage_order: Option<i32>,
    pub gdd_trigger: Decimal,
    pub gdd_tolerance: Option<Decimal>,
    pub scheduled_date: Date,
    pub priority: Option<i32>,
    pub source: Option<String>,
    pub status: String,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<Decimal>,
    pub amount: Option<Decimal>,
    pub amount_unit: Option<String>,
}
