//! Validates reorganize orchestration progress patch payloads.

use crate::cultivation_plan::dtos::{
    ReorganizeOrchestrationProgressPatch, ReorganizePipelinePhase,
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

    if let Some(Some(phase)) = &patch.pipeline_phase {
        validate_pipeline_phase(phase)?;
    }
    if let Some(Some(phase)) = &patch.pipeline_failed_phase {
        validate_pipeline_phase(phase)?;
    }

    Ok(())
}

fn validate_pipeline_phase(phase: &ReorganizePipelinePhase) -> Result<(), RecordInvalidError> {
    let _ = phase.as_str();
    Ok(())
}

pub fn parse_pipeline_phase(raw: &str) -> Result<ReorganizePipelinePhase, RecordInvalidError> {
    ReorganizePipelinePhase::parse(raw).ok_or_else(|| {
        RecordInvalidError::new(
            Some(format!("invalid pipeline phase: {raw}")),
            None,
        )
    })
}

#[cfg(test)]
mod policies_plan_variance_learning_orchestration_progress_policy_test_inline {
    use super::*;

    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/policies_plan_variance_learning_orchestration_progress_policy_test.rs"
    ));
}
