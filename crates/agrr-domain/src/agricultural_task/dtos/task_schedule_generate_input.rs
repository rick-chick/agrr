//! Input for [`crate::agricultural_task::interactors::TaskScheduleGenerateInteractor`].

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TaskScheduleGenerateInput {
    pub cultivation_plan_id: i64,
}

impl TaskScheduleGenerateInput {
    pub fn new(cultivation_plan_id: i64) -> Self {
        Self { cultivation_plan_id }
    }
}
