use thiserror::Error;

/// Ruby: `Domain::FieldCultivation::Errors::FieldCultivationSyncEmptyError`
#[derive(Debug, Clone, Copy, PartialEq, Eq, Error)]
#[error("field cultivation sync empty")]
pub struct FieldCultivationSyncEmptyError;
