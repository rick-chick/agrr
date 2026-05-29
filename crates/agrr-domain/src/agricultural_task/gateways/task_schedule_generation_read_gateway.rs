//! Narrow read ports for task schedule generation (Ruby: `TaskScheduleGenerationReadGateway`).

use rust_decimal::Decimal;
use serde_json::Value;
use time::Date;

use super::cultivation_plan_gateway::TaskScheduleRelatedTask;

#[derive(Debug, Clone)]
pub struct TaskSchedulePlanRow {
    pub id: i64,
    pub predicted_weather_data: Value,
    pub calculated_planning_start_date: Option<Date>,
}

#[derive(Debug, Clone)]
pub struct TaskScheduleFieldCultivationRow {
    pub id: i64,
    pub start_date: Option<Date>,
    pub crop_id: Option<i64>,
}

#[derive(Debug, Clone)]
pub struct TaskScheduleCropRow {
    pub id: i64,
    pub name: String,
}

#[derive(Debug, Clone)]
pub struct TaskScheduleTemplateRow {
    pub agricultural_task: Option<TaskScheduleRelatedTask>,
}

#[derive(Debug, Clone)]
pub struct TaskScheduleBlueprintRow {
    pub id: i64,
    pub task_type: String,
    pub gdd_trigger: Option<Decimal>,
    pub gdd_tolerance: Option<Decimal>,
    pub description: Option<String>,
    pub stage_name: Option<String>,
    pub stage_order: Option<i32>,
    pub priority: Option<i32>,
    pub source: Option<String>,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<Decimal>,
    pub amount: Option<Decimal>,
    pub amount_unit: Option<String>,
    pub agricultural_task: Option<TaskScheduleRelatedTask>,
}

pub trait TaskScheduleGenerationReadGateway: Send + Sync {
    fn find_plan_row(
        &self,
        plan_id: i64,
    ) -> Result<TaskSchedulePlanRow, Box<dyn std::error::Error + Send + Sync>>;

    fn list_field_cultivation_rows(
        &self,
        plan_id: i64,
    ) -> Result<Vec<TaskScheduleFieldCultivationRow>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_crop_row(
        &self,
        crop_id: i64,
    ) -> Result<TaskScheduleCropRow, Box<dyn std::error::Error + Send + Sync>>;

    fn list_crop_task_template_rows(
        &self,
        crop_id: i64,
    ) -> Result<Vec<TaskScheduleTemplateRow>, Box<dyn std::error::Error + Send + Sync>>;

    fn list_crop_task_schedule_blueprint_rows(
        &self,
        crop_id: i64,
    ) -> Result<Vec<TaskScheduleBlueprintRow>, Box<dyn std::error::Error + Send + Sync>>;

    fn build_crop_agrr_requirement(
        &self,
        crop_id: i64,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>>;
}
