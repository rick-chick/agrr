// Tests for `policies/optimization_chain_orchestration_progress_policy.rs`.

use crate::cultivation_plan::dtos::{
    ReorganizeOrchestrationProgressPatch, ReorganizeOrchestrationProgressRead,
    PIPELINE_PHASE_COMPLETED, PIPELINE_PHASE_FAILED, PIPELINE_PHASE_REGENERATE,
    PIPELINE_PHASE_SYNC_VERIFY,
};
use crate::cultivation_plan::policies::optimization_chain_orchestration_progress_policy::{
    orchestration_patch_for_chain_step_failure, orchestration_patch_for_chain_step_success,
    OptimizationChainOrchestrationStep,
};

fn active_pipeline() -> ReorganizeOrchestrationProgressRead {
    ReorganizeOrchestrationProgressRead {
        pipeline_active: true,
        current_phase: "optimizing".into(),
        ..Default::default()
    }
}

#[test]
fn no_patch_when_pipeline_inactive() {
    let current = ReorganizeOrchestrationProgressRead::default();
    assert!(orchestration_patch_for_chain_step_success(
        OptimizationChainOrchestrationStep::Optimization,
        &current
    )
    .is_none());
}

#[test]
fn optimization_success_advances_to_regenerate_and_marks_placement() {
    let patch = orchestration_patch_for_chain_step_success(
        OptimizationChainOrchestrationStep::Optimization,
        &active_pipeline(),
    )
    .expect("patch expected");

    assert_eq!(
        ReorganizeOrchestrationProgressPatch {
            placement: Some(true),
            current_phase: Some(PIPELINE_PHASE_REGENERATE.into()),
            ..Default::default()
        },
        patch
    );
}

#[test]
fn task_schedule_generation_success_advances_to_sync_verify() {
    let current = ReorganizeOrchestrationProgressRead {
        pipeline_active: true,
        current_phase: PIPELINE_PHASE_REGENERATE.into(),
        placement: true,
        ..Default::default()
    };

    let patch = orchestration_patch_for_chain_step_success(
        OptimizationChainOrchestrationStep::TaskScheduleGeneration,
        &current,
    )
    .expect("patch expected");

    assert_eq!(
        ReorganizeOrchestrationProgressPatch {
            regenerate: Some(true),
            current_phase: Some(PIPELINE_PHASE_SYNC_VERIFY.into()),
            ..Default::default()
        },
        patch
    );
}

#[test]
fn plan_finalize_success_completes_pipeline() {
    let current = ReorganizeOrchestrationProgressRead {
        pipeline_active: true,
        current_phase: PIPELINE_PHASE_SYNC_VERIFY.into(),
        placement: true,
        regenerate: true,
        ..Default::default()
    };

    let patch = orchestration_patch_for_chain_step_success(
        OptimizationChainOrchestrationStep::PlanFinalize,
        &current,
    )
    .expect("patch expected");

    assert_eq!(
        ReorganizeOrchestrationProgressPatch {
            sync_verify: Some(true),
            pipeline_active: Some(false),
            current_phase: Some(PIPELINE_PHASE_COMPLETED.into()),
            last_error: Some(None),
            ..Default::default()
        },
        patch
    );
}

#[test]
fn chain_step_failure_marks_failed_with_error() {
    let patch = orchestration_patch_for_chain_step_failure(&active_pipeline(), "daemon unavailable")
        .expect("patch expected");

    assert_eq!(
        ReorganizeOrchestrationProgressPatch {
            current_phase: Some(PIPELINE_PHASE_FAILED.into()),
            last_error: Some(Some("daemon unavailable".into())),
            ..Default::default()
        },
        patch
    );
}

#[test]
fn chain_step_failure_noop_when_pipeline_inactive() {
    assert!(orchestration_patch_for_chain_step_failure(
        &ReorganizeOrchestrationProgressRead::default(),
        "daemon unavailable"
    )
    .is_none());
}
