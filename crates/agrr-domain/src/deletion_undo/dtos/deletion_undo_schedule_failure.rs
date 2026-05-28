//! Ruby: `Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailure`

/// Ruby failure reason symbols.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeletionUndoScheduleFailureReason {
    UndoSystemError,
    ValidationError,
    AssociationInUse,
    Forbidden,
}

/// Ruby: `Domain::DeletionUndo::Dtos::DeletionUndoScheduleFailure`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeletionUndoScheduleFailure {
    pub reason: DeletionUndoScheduleFailureReason,
    pub detail_message: Option<String>,
}

impl DeletionUndoScheduleFailure {
    pub fn new(reason: DeletionUndoScheduleFailureReason, detail_message: Option<String>) -> Self {
        Self {
            reason,
            detail_message,
        }
    }

    pub fn undo_system_error(detail: impl Into<String>) -> Self {
        Self::new(
            DeletionUndoScheduleFailureReason::UndoSystemError,
            Some(detail.into()),
        )
    }

    pub fn validation_error(detail: impl Into<String>) -> Self {
        Self::new(
            DeletionUndoScheduleFailureReason::ValidationError,
            Some(detail.into()),
        )
    }

    pub fn association_in_use(detail: impl Into<String>) -> Self {
        Self::new(
            DeletionUndoScheduleFailureReason::AssociationInUse,
            Some(detail.into()),
        )
    }

    pub fn forbidden() -> Self {
        Self::new(DeletionUndoScheduleFailureReason::Forbidden, None)
    }
}
