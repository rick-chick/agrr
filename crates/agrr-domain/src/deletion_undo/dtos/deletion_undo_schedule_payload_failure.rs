//! Ruby: `Domain::DeletionUndo::Dtos::DeletionUndoSchedulePayloadFailure`

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeletionUndoSchedulePayloadFailureReason {
    MissingUndoToken,
}

/// Ruby: `Domain::DeletionUndo::Dtos::DeletionUndoSchedulePayloadFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeletionUndoSchedulePayloadFailure {
    pub reason: DeletionUndoSchedulePayloadFailureReason,
    pub http_status: u16,
}

impl DeletionUndoSchedulePayloadFailure {
    pub fn missing_undo_token() -> Self {
        Self {
            reason: DeletionUndoSchedulePayloadFailureReason::MissingUndoToken,
            http_status: 422,
        }
    }
}
