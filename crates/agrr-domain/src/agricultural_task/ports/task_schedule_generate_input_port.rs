//! Input port for generating task schedules for a cultivation plan.

use crate::agricultural_task::dtos::TaskScheduleGenerateInput;

pub trait TaskScheduleGenerateInputPort: Send + Sync {
    fn call(
        &self,
        input: TaskScheduleGenerateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
