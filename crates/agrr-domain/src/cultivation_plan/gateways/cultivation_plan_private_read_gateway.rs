//! Ruby: `Domain::CultivationPlan::Gateways::CultivationPlanPrivateReadGateway`
//!
//! Index / count only. Plan / timeline / optimization snapshots use dedicated read gateways
//! + domain mapper assembles read snapshots (Gateway boundary).

use crate::cultivation_plan::dtos::{
    OptimizationPlanSnapshot, PrivatePlanIndexPlanRow, PrivatePlanReadSnapshot,
    task_schedule_timeline_snapshot::TaskScheduleTimelineSnapshot,
};

pub trait CultivationPlanPrivateReadGateway: Send + Sync {
    fn list_private_plan_index_rows_by_user_id(
        &self,
        user_id: i64,
    ) -> Result<Vec<PrivatePlanIndexPlanRow>, Box<dyn std::error::Error + Send + Sync>>;
}

/// Rust parity gap: composite read until narrow gateways are ported from Ruby.
pub trait CultivationPlanPrivateSnapshotReadGateway: Send + Sync {
    fn find_plan_read_snapshot_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<PrivatePlanReadSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn find_task_schedule_timeline_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<TaskScheduleTimelineSnapshot, Box<dyn std::error::Error + Send + Sync>>;

    fn find_optimization_snapshot_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<OptimizationPlanSnapshot, Box<dyn std::error::Error + Send + Sync>>;
}
