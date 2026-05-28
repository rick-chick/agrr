use thiserror::Error;

/// Ruby: `FieldCultivationSyncReferenceError::KIND_*`
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SyncReferenceKind {
    FieldMissing,
    PlanCropMissing,
    PlanCropAmbiguous,
    StartDateInvalid,
    CompletionDateInvalid,
}

/// Ruby: `Domain::FieldCultivation::Errors::FieldCultivationSyncReferenceError`
#[derive(Debug, Clone, PartialEq, Eq, Error)]
#[error("{message}")]
pub struct FieldCultivationSyncReferenceError {
    pub kind: SyncReferenceKind,
    pub field_id: Option<i64>,
    pub crop_id: Option<String>,
    pub allocation_id: Option<String>,
    pub raw_value: Option<String>,
    message: String,
}

impl FieldCultivationSyncReferenceError {
    pub fn new(
        kind: SyncReferenceKind,
        message: impl Into<String>,
        field_id: Option<i64>,
        crop_id: Option<String>,
        allocation_id: Option<String>,
        raw_value: Option<String>,
    ) -> Self {
        Self {
            kind,
            message: message.into(),
            field_id,
            crop_id,
            allocation_id,
            raw_value,
        }
    }
}
