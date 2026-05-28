use crate::deletion_undo::dtos::DeletionUndoRestoreOutput;
use crate::shared::dtos::Error;

/// Ruby: `Domain::DeletionUndo::Ports::DeletionUndoRestoreOutputPort`
pub trait DeletionUndoRestoreOutputPort {
    fn on_success(&mut self, output: DeletionUndoRestoreOutput);
    fn on_failure(&mut self, error: Error);
}
