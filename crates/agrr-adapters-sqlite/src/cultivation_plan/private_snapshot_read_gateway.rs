//! Narrow read for `PrivateOwnedPlanDetailInteractor` — `find_plan_read_snapshot_by_plan_id` only.

use crate::cultivation_plan::rest_plan_read::{
    private_plan_read_snapshot_from_rest, CultivationPlanRestPlanReadSqliteGateway,
};
use crate::cultivation_plan::task_schedule_timeline_read;
use crate::pool::SqlitePool;
use agrr_domain::cultivation_plan::dtos::{
    OptimizationPlanSnapshot, PrivatePlanReadSnapshot,
    task_schedule_timeline_snapshot::TaskScheduleTimelineSnapshot,
};
use agrr_domain::cultivation_plan::gateways::CultivationPlanPrivateSnapshotReadGateway;

pub struct CultivationPlanPrivateSnapshotReadSqliteGateway {
    rest: CultivationPlanRestPlanReadSqliteGateway,
    pool: SqlitePool,
}

impl CultivationPlanPrivateSnapshotReadSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self {
            rest: CultivationPlanRestPlanReadSqliteGateway::new(pool.clone()),
            pool,
        }
    }
}

fn read_only_err(feature: &str) -> Box<dyn std::error::Error + Send + Sync> {
    Box::new(std::io::Error::new(
        std::io::ErrorKind::Unsupported,
        format!("{feature} not supported in P6 private plan show read slice"),
    ))
}

impl CultivationPlanPrivateSnapshotReadGateway for CultivationPlanPrivateSnapshotReadSqliteGateway {
    fn find_plan_read_snapshot_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<PrivatePlanReadSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        let header = self.rest.find_plan_header_snapshot_by_plan_id(plan_id)?;
        let fields = self
            .rest
            .list_rest_plan_field_row_snapshots_by_plan_id(plan_id)?;
        let cultivations = self
            .rest
            .list_rest_plan_cultivation_row_snapshots_by_plan_id(plan_id)?;
        let palette_crop_ids = self.rest.list_palette_crop_ids_by_plan_id(plan_id)?;
        Ok(private_plan_read_snapshot_from_rest(
            header,
            fields,
            cultivations,
            palette_crop_ids,
        ))
    }

    fn find_task_schedule_timeline_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<TaskScheduleTimelineSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        task_schedule_timeline_read::load_task_schedule_timeline_snapshot(&self.pool, plan_id)
    }

    fn find_optimization_snapshot_by_plan_id(
        &self,
        _plan_id: i64,
    ) -> Result<OptimizationPlanSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        Err(read_only_err("optimization_snapshot"))
    }
}
