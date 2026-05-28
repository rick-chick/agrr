use crate::deletion_undo::dtos::DeletionUndoScheduleFailure;
use crate::deletion_undo::entities::DeletionUndoEntity;

/// Ruby: `Domain::DeletionUndo::Ports::DeletionUndoScheduleOutputPort`
pub trait DeletionUndoScheduleOutputPort {
    fn on_success(&mut self, entity: DeletionUndoEntity);
    fn on_failure(&mut self, failure: DeletionUndoScheduleFailure);
}
