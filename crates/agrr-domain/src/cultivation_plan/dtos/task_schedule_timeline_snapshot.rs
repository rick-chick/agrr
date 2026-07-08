//! Ruby: `Domain::CultivationPlan::Dtos::TaskScheduleTimelineSnapshot`

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
    pub task_schedule_sync_state: String,
    pub task_schedule_sync_error: Option<String>,
    pub task_schedule_sync_error_crop_id: Option<i64>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleTimelineFieldRead {
    pub id: i64,
    pub name: String,
    pub crop_name: String,
    pub area_sqm: f64,
    pub field_cultivation_id: i64,
    pub crop_id: i64,
    pub cultivation_start_date: Option<Date>,
    pub cultivation_end_date: Option<Date>,
    pub task_options: Vec<TaskScheduleTimelineTaskOptionRead>,
    pub schedules: Vec<TaskScheduleTimelineScheduleRead>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleTimelineTaskOptionRead {
    pub agricultural_task_id: i64,
    pub name: String,
    pub task_type: String,
    pub description: Option<String>,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<f64>,
    pub required_tools: Option<Vec<String>>,
    pub skill_level: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleTimelineScheduleRead {
    pub category: String,
    pub items: Vec<TaskScheduleTimelineScheduleItemRead>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleTimelineScheduleItemRead {
    pub id: i64,
    pub name: String,
    pub task_type: String,
    pub scheduled_date: Option<String>,
    pub stage_name: Option<String>,
    pub stage_order: Option<i32>,
    pub gdd_trigger: Option<f64>,
    pub gdd_tolerance: Option<f64>,
    pub priority: Option<i32>,
    pub source: String,
    pub weather_dependency: Option<String>,
    pub time_per_sqm: Option<f64>,
    pub amount: Option<f64>,
    pub amount_unit: Option<String>,
    pub status: String,
    pub agricultural_task_id: Option<i64>,
    pub field_cultivation_id: i64,
    pub agricultural_task: Option<TaskScheduleTimelineAgriculturalTaskRead>,
    pub rescheduled_at: Option<String>,
    pub cancelled_at: Option<String>,
    pub completed: bool,
    pub work_records: Vec<TaskScheduleTimelineWorkRecordSummaryRead>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleTimelineAgriculturalTaskRead {
    pub name: String,
    pub description: Option<String>,
    pub time_per_sqm: Option<f64>,
    pub weather_dependency: Option<String>,
    pub required_tools: Option<Vec<String>>,
    pub skill_level: Option<String>,
    pub task_type: Option<String>,
}

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleTimelineWorkRecordSummaryRead {
    pub id: i64,
    pub actual_date: String,
    pub notes: Option<String>,
}
