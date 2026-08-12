//! Gateway for persisted plan variance learning snapshots.

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
}
