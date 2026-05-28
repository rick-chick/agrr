//! Plan-save interactors raise Ruby `RecordNotFound` with a message (not the empty shared type).

#[derive(Debug, Clone, PartialEq, Eq, thiserror::Error)]
#[error("{0}")]
pub struct PlanSaveRecordNotFoundError(pub String);
