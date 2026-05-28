//! Ruby: `Domain::CultivationPlan::Dtos::TaskScheduleTimelineSnapshot`

use serde_json::Value;
use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleTimelineSnapshot {
    pub plan: TaskScheduleTimelinePlanRead,
    pub fields: Vec<TaskScheduleTimelineFieldRead>,
    pub scheduled_dates: Vec<Date>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleTimelinePlanRead {
    pub id: i64,
    pub display_name: String,
    pub status: String,
    pub planning_start_date: Option<Date>,
    pub planning_end_date: Option<Date>,
    pub timeline_generated_at: Option<String>,
    pub farm_display_name: String,
    pub total_area: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleTimelineFieldRead {
    pub id: i64,
    pub name: String,
    pub crop_name: String,
    pub area_sqm: f64,
    pub field_cultivation_id: i64,
    pub crop_id: i64,
    pub task_options: Vec<Value>,
    pub schedules: Vec<Value>,
}
