/// Context for task schedule generation.
#[derive(Debug, Clone)]
pub struct TaskSchedulePlanContext {
    pub plan: TaskSchedulePlan,
}

#[derive(Debug, Clone)]
pub struct TaskSchedulePlan {
    pub id: i64,
    pub predicted_weather_data: serde_json::Value,
    pub field_cultivations: Vec<TaskScheduleFieldCultivation>,
    pub calculated_planning_start_date: Option<time::Date>,
}

#[derive(Debug, Clone)]
pub struct TaskScheduleFieldCultivation {
    pub id: i64,
    pub crop: Option<TaskScheduleCrop>,
    pub start_date: Option<time::Date>,
}

#[derive(Debug, Clone)]
pub struct TaskScheduleCrop {
    pub id: i64,
    pub name: String,
    pub crop_task_templates: Vec<TaskScheduleCropTaskTemplate>,
    pub crop_task_schedule_blueprints: Vec<TaskScheduleBlueprint>,
}

#[derive(Debug, Clone)]
pub struct TaskScheduleCropTaskTemplate {
    pub agricultural_task: Option<TaskScheduleRelatedTask>,
}

#[derive(Debug, Clone)]
pub struct TaskScheduleRelatedTask {
    pub id: i64,
    pub name: String,
    pub description: Option<String>,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<rust_decimal::Decimal>,
}

#[derive(Debug, Clone)]
pub struct TaskScheduleBlueprint {
    pub task_type: String,
    pub gdd_trigger: Option<rust_decimal::Decimal>,
    pub gdd_tolerance: Option<rust_decimal::Decimal>,
    pub description: Option<String>,
    pub stage_name: Option<String>,
    pub stage_order: Option<i32>,
    pub priority: Option<i32>,
    pub source: Option<String>,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<rust_decimal::Decimal>,
    pub amount: Option<rust_decimal::Decimal>,
    pub amount_unit: Option<String>,
    pub agricultural_task: Option<TaskScheduleRelatedTask>,
}

/// Ruby: `CultivationPlanGateway` — transaction boundary for task schedule generation
pub trait CultivationPlanGateway: Send + Sync {
    fn within_transaction<F, T>(&self, block: F) -> T
    where
        F: FnOnce() -> T;
}
