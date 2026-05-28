//! Schedules deletion undo (adapter implements via `DeletionUndoScheduleInteractor`).

use crate::deletion_undo::dtos::DeletionUndoScheduleInput;

pub trait DeletionUndoSchedulePort: Send + Sync {
    fn call(
        &self,
        input: DeletionUndoScheduleInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
