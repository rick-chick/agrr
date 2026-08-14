//! Validates reorganize orchestration progress patch payloads.

use crate::cultivation_plan::dtos::{
    ReorganizeOrchestrationProgressPatch, PIPELINE_PHASES,
};
use crate::shared::exceptions::RecordInvalidError;

pub fn validate_reorganize_orchestration_progress_patch(
    patch: &ReorganizeOrchestrationProgressPatch,
) -> Result<(), RecordInvalidError> {
    if patch.is_empty() {
        return Err(RecordInvalidError::new(
            Some("reorganize_orchestration_progress is required".into()),
            None,
        ));
    }

    if let Some(phase) = &patch.current_phase {
        if !PIPELINE_PHASES.contains(&phase.as_str()) {
            return Err(RecordInvalidError::new(
                Some("invalid pipeline current_phase".into()),
                None,
            ));
        }
    }

    Ok(())
}

#[cfg(test)]
mod policies_plan_variance_learning_orchestration_progress_policy_test_inline {
    use super::*;

    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/policies_plan_variance_learning_orchestration_progress_policy_test.rs"
    ));
}
