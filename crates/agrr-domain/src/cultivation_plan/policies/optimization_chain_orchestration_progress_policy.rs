//! Maps optimization job chain step outcomes to reorganize orchestration progress patches.

use crate::cultivation_plan::dtos::{
    ReorganizeOrchestrationProgressPatch, ReorganizeOrchestrationProgressRead,
    PIPELINE_PHASE_COMPLETED, PIPELINE_PHASE_FAILED, PIPELINE_PHASE_REGENERATE,
    PIPELINE_PHASE_SYNC_VERIFY,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OptimizationChainOrchestrationStep {
    Optimization,
    TaskScheduleGeneration,
    PlanFinalize,
}

pub fn orchestration_patch_for_chain_step_success(
    step: OptimizationChainOrchestrationStep,
    current: &ReorganizeOrchestrationProgressRead,
) -> Option<ReorganizeOrchestrationProgressPatch> {
    if !current.pipeline_active {
        return None;
    }

    Some(match step {
        OptimizationChainOrchestrationStep::Optimization => ReorganizeOrchestrationProgressPatch {
            placement: Some(true),
            current_phase: Some(PIPELINE_PHASE_REGENERATE.into()),
            ..Default::default()
        },
        OptimizationChainOrchestrationStep::TaskScheduleGeneration => {
            ReorganizeOrchestrationProgressPatch {
                regenerate: Some(true),
                current_phase: Some(PIPELINE_PHASE_SYNC_VERIFY.into()),
                ..Default::default()
            }
        }
        OptimizationChainOrchestrationStep::PlanFinalize => ReorganizeOrchestrationProgressPatch {
            sync_verify: Some(true),
            pipeline_active: Some(false),
            current_phase: Some(PIPELINE_PHASE_COMPLETED.into()),
            last_error: Some(None),
            ..Default::default()
        },
    })
}

pub fn orchestration_patch_for_chain_step_failure(
    current: &ReorganizeOrchestrationProgressRead,
    error: &str,
) -> Option<ReorganizeOrchestrationProgressPatch> {
    if !current.pipeline_active {
        return None;
    }

    Some(ReorganizeOrchestrationProgressPatch {
        current_phase: Some(PIPELINE_PHASE_FAILED.into()),
        last_error: Some(Some(error.to_string())),
        ..Default::default()
    })
}

#[cfg(test)]
mod policies_optimization_chain_orchestration_progress_policy_test_inline {
    use super::*;

    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/policies_optimization_chain_orchestration_progress_policy_test.rs"
    ));
}
