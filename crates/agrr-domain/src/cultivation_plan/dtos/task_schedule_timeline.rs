//! Ruby: `Domain::CultivationPlan::Dtos::TaskScheduleTimeline`

use super::task_schedule_timeline_snapshot::{
    TaskScheduleTimelineFieldRead, TaskScheduleTimelinePlanRead,
};
use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct TaskScheduleTimeline {
    pub plan: TaskScheduleTimelinePlanRead,
    pub fields: Vec<TaskScheduleTimelineFieldRead>,
    pub scheduled_dates: Vec<Date>,
    pub today: Date,
}
