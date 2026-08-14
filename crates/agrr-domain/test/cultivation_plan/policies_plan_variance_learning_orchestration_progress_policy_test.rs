// Tests for `policies/plan_variance_learning_orchestration_progress_policy.rs`.

use crate::cultivation_plan::dtos::ReorganizeOrchestrationProgressPatch;
use crate::cultivation_plan::dtos::ReorganizePipelinePhase;
use crate::cultivation_plan::policies::plan_variance_learning_orchestration_progress_policy::{
    parse_pipeline_phase, validate_reorganize_orchestration_progress_patch,
};

#[test]
fn rejects_empty_patch() {
    let patch = ReorganizeOrchestrationProgressPatch::default();
    let err =
        validate_reorganize_orchestration_progress_patch(&patch).expect_err("empty patch");
    assert_eq!(
        err.detail_message(),
        Some("reorganize_orchestration_progress is required")
    );
}

#[test]
fn accepts_placement_update() {
    let patch = ReorganizeOrchestrationProgressPatch {
        placement: Some(true),
        ..Default::default()
    };
    assert!(validate_reorganize_orchestration_progress_patch(&patch).is_ok());
}

#[test]
fn accepts_return_to_learn_update() {
    let patch = ReorganizeOrchestrationProgressPatch {
        return_to_learn: Some(true),
        ..Default::default()
    };
    assert!(validate_reorganize_orchestration_progress_patch(&patch).is_ok());
}

#[test]
fn accepts_pipeline_phase_update() {
    let patch = ReorganizeOrchestrationProgressPatch {
        pipeline_active: Some(true),
        pipeline_phase: Some(Some(ReorganizePipelinePhase::Placement)),
        ..Default::default()
    };
    assert!(validate_reorganize_orchestration_progress_patch(&patch).is_ok());
}

#[test]
fn rejects_invalid_pipeline_phase_string() {
    let err = parse_pipeline_phase("invalid").expect_err("invalid phase");
    assert_eq!(
        err.detail_message(),
        Some("invalid pipeline phase: invalid".into())
    );
}
