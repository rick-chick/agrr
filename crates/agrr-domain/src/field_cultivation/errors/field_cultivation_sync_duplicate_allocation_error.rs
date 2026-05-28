use thiserror::Error;

/// Ruby: `Domain::FieldCultivation::Errors::FieldCultivationSyncDuplicateAllocationError`
#[derive(Debug, Clone, PartialEq, Eq, Error)]
#[error("duplicate allocation ids: {duplicate_ids:?}")]
pub struct FieldCultivationSyncDuplicateAllocationError {
    pub duplicate_ids: Vec<String>,
}

impl FieldCultivationSyncDuplicateAllocationError {
    pub fn new(duplicate_ids: Vec<String>) -> Self {
        Self { duplicate_ids }
    }
}
