use rust_decimal::Decimal;

/// Masters crop task schedule blueprint row (includes DB id).
#[derive(Debug, Clone, PartialEq)]
pub struct MastersCropTaskScheduleBlueprint {
    pub id: i64,
    pub crop_id: i64,
    pub agricultural_task_id: Option<i64>,
    pub source_agricultural_task_id: Option<i64>,
    pub stage_order: Option<i32>,
    pub stage_name: Option<String>,
    pub gdd_trigger: Option<Decimal>,
    pub gdd_tolerance: Option<Decimal>,
    pub task_type: String,
    pub source: String,
    pub priority: i32,
    pub amount: Option<Decimal>,
    pub amount_unit: Option<String>,
    pub description: Option<String>,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<Decimal>,
    pub name: Option<String>,
    pub created_at: Option<String>,
    pub updated_at: Option<String>,
}
