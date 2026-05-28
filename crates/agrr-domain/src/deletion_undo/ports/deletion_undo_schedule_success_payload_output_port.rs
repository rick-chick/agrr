use crate::deletion_undo::dtos::{
    DeletionUndoSchedulePayloadFailure, DeletionUndoScheduleSuccessOutput,
};

/// Ruby: payload interactor output port (implicit in Ruby interactor).
pub trait DeletionUndoScheduleSuccessPayloadOutputPort {
    fn on_success(&mut self, output: DeletionUndoScheduleSuccessOutput);
    fn on_failure(&mut self, failure: DeletionUndoSchedulePayloadFailure);
}
