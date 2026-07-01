//! Input for [`crate::agricultural_task::interactors::RunTaskScheduleGenerationInteractor`].

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct RunTaskScheduleGenerationInput {
    pub plan_id: i64,
}

impl RunTaskScheduleGenerationInput {
    pub fn new(plan_id: i64) -> Self {
        Self { plan_id }
    }
}
