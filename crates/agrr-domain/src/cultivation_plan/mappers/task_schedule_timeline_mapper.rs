//! Ruby: `Domain::CultivationPlan::Mappers::TaskScheduleTimelineMapper`

use crate::cultivation_plan::dtos::{
    TaskScheduleTimeline, TaskScheduleTimelineSnapshot,
};
use time::Date;

pub struct TaskScheduleTimelineMapper;

impl TaskScheduleTimelineMapper {
    pub fn call(read_model: TaskScheduleTimelineSnapshot, today: Date) -> TaskScheduleTimeline {
        TaskScheduleTimeline {
            plan: read_model.plan,
            fields: read_model.fields,
            scheduled_dates: read_model.scheduled_dates,
            today,
        }
    }
}
