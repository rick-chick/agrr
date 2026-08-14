//! Persisted variance learning snapshot copied from a source plan at new-plan creation.

use std::collections::BTreeMap;

use super::learn_handoff_state::LearnHandoffStateRead;
use super::plan_vs_actual::PlanVsActualSummaryRead;
use super::reorganize_orchestration_progress::ReorganizeOrchestrationProgressRead;

#[derive(Debug, Clone, PartialEq)]
pub struct PlanVarianceLearningSnapshotRead {
    pub plan_id: i64,
    pub source_plan_id: Option<i64>,
    pub summary: Option<PlanVsActualSummaryRead>,
    pub proposal_application_progress: BTreeMap<String, String>,
    pub reorganize_orchestration_progress: ReorganizeOrchestrationProgressRead,
    pub learn_handoff: LearnHandoffStateRead,
}

pub fn assemble_plan_variance_learning_snapshot(
    plan_id: i64,
    base: Option<PlanVarianceLearningSnapshotRead>,
    proposal_application_progress: BTreeMap<String, String>,
    reorganize_orchestration_progress: ReorganizeOrchestrationProgressRead,
    learn_handoff: LearnHandoffStateRead,
) -> PlanVarianceLearningSnapshotRead {
    match base {
        Some(existing) => PlanVarianceLearningSnapshotRead {
            plan_id: existing.plan_id,
            source_plan_id: existing.source_plan_id,
            summary: existing.summary,
            proposal_application_progress,
            reorganize_orchestration_progress,
            learn_handoff,
        },
        None => PlanVarianceLearningSnapshotRead {
            plan_id,
            source_plan_id: None,
            summary: None,
            proposal_application_progress,
            reorganize_orchestration_progress,
            learn_handoff,
        },
    }
}
