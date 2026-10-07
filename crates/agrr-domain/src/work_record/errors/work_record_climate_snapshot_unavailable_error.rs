use thiserror::Error;

use crate::field_cultivation::dtos::FieldCultivationClimateFailure;

#[derive(Debug, Error)]
#[error("climate snapshot unavailable")]
pub struct WorkRecordClimateSnapshotUnavailableError {
    pub failure: FieldCultivationClimateFailure,
}

impl WorkRecordClimateSnapshotUnavailableError {
    pub fn new(failure: FieldCultivationClimateFailure) -> Self {
        Self { failure }
    }
}
