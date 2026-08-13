//! Persisted variance learning snapshot copied from a source plan at new-plan creation.

use std::collections::BTreeMap;

use super::plan_vs_actual::PlanVsActualSummaryRead;

#[derive(Debug, Clone, PartialEq)]
pub struct PlanVarianceLearningSnapshotRead {
    pub plan_id: i64,
    pub source_plan_id: Option<i64>,
    pub summary: Option<PlanVsActualSummaryRead>,
    pub proposal_application_progress: BTreeMap<String, String>,
}
