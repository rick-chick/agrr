//! Input port for persisting and broadcasting task schedule sync metadata.

use crate::agricultural_task::dtos::UpdateTaskScheduleSyncStateInput;

pub trait TaskScheduleSyncStateUpdateInputPort: Send + Sync {
    fn call(
        &self,
        input: UpdateTaskScheduleSyncStateInput<'_>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
