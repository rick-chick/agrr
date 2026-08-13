//! Gateway for persisted plan variance learning snapshots.

use std::collections::BTreeMap;

use crate::cultivation_plan::dtos::{
    PlanVarianceLearningSnapshotRead, PlanVsActualSummaryRead,
};

pub trait PlanVarianceLearningGateway: Send + Sync {
    fn save(
        &self,
        plan_id: i64,
        source_plan_id: i64,
        summary: &PlanVsActualSummaryRead,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn find_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Option<PlanVarianceLearningSnapshotRead>, Box<dyn std::error::Error + Send + Sync>>;

    fn find_proposal_application_progress_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<BTreeMap<String, String>, Box<dyn std::error::Error + Send + Sync>>;

    fn upsert_proposal_application_progress(
        &self,
        plan_id: i64,
        updates: &BTreeMap<String, String>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
