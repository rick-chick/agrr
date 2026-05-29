//! Implements domain `CultivationPlanRestPlanReadGateway` on SQLite per-table reads.

use super::rest_plan_read::{
    CultivationPlanRestPlanReadSqliteGateway, RestPlanCropRowSnapshot, RestPlanCultivationRowSnapshot,
    RestPlanFieldRowSnapshot, RestPlanHeaderSnapshot,
};
use agrr_domain::cultivation_plan::dtos::rest_plan_snapshots::{
    CultivationPlanRestPlanCropRowSnapshot, CultivationPlanRestPlanCultivationRowSnapshot,
    CultivationPlanRestPlanFieldRowSnapshot, CultivationPlanRestPlanHeaderSnapshot,
};
use agrr_domain::cultivation_plan::gateways::CultivationPlanRestPlanReadGateway;
use agrr_domain::shared::exceptions::RecordNotFoundError;

pub struct CultivationPlanRestPlanReadDomainSqliteGateway {
    inner: CultivationPlanRestPlanReadSqliteGateway,
}

impl CultivationPlanRestPlanReadDomainSqliteGateway {
    pub fn new(inner: CultivationPlanRestPlanReadSqliteGateway) -> Self {
        Self { inner }
    }
}

fn map_header(h: RestPlanHeaderSnapshot) -> CultivationPlanRestPlanHeaderSnapshot {
    CultivationPlanRestPlanHeaderSnapshot {
        id: h.id,
        user_id: h.user_id,
        plan_year: h.plan_year,
        plan_name: h.plan_name,
        display_name: h.display_name,
        plan_type: h.plan_type,
        status: h.status,
        total_area: h.total_area,
        planning_start_date: h.planning_start_date,
        planning_end_date: h.planning_end_date,
        calculated_planning_start_date: h.calculated_planning_start_date,
        prediction_target_end_date: h.prediction_target_end_date,
        total_profit: h.total_profit,
        total_revenue: h.total_revenue,
        total_cost: h.total_cost,
        farm_display_name: h.farm_display_name,
        farm_region: h.farm_region,
    }
}

fn map_field(f: RestPlanFieldRowSnapshot) -> CultivationPlanRestPlanFieldRowSnapshot {
    CultivationPlanRestPlanFieldRowSnapshot {
        id: f.id,
        display_name: f.display_name,
        area: f.area,
        daily_fixed_cost: f.daily_fixed_cost,
    }
}

fn map_crop(c: RestPlanCropRowSnapshot) -> CultivationPlanRestPlanCropRowSnapshot {
    CultivationPlanRestPlanCropRowSnapshot {
        id: c.id,
        display_name: c.display_name,
        area_per_unit: c.area_per_unit,
        revenue_per_area: c.revenue_per_area,
    }
}

fn map_cultivation(
    fc: RestPlanCultivationRowSnapshot,
) -> CultivationPlanRestPlanCultivationRowSnapshot {
    CultivationPlanRestPlanCultivationRowSnapshot {
        id: fc.id,
        cultivation_plan_field_id: fc.cultivation_plan_field_id,
        field_display_name: fc.field_display_name,
        cultivation_plan_crop_id: fc.cultivation_plan_crop_id,
        crop_display_name: fc.crop_display_name,
        area: fc.area,
        start_date: fc.start_date,
        completion_date: fc.completion_date,
        cultivation_days: fc.cultivation_days,
        estimated_cost: fc.estimated_cost,
        optimization_result: fc.optimization_result,
        status: fc.status,
    }
}

fn map_err(err: Box<dyn std::error::Error + Send + Sync>) -> Box<dyn std::error::Error + Send + Sync> {
    if err.downcast_ref::<rusqlite::Error>().is_some_and(|e| {
        matches!(e, rusqlite::Error::QueryReturnedNoRows)
    }) {
        return Box::new(RecordNotFoundError);
    }
    err
}

impl CultivationPlanRestPlanReadGateway for CultivationPlanRestPlanReadDomainSqliteGateway {
    fn find_plan_header_snapshot_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<CultivationPlanRestPlanHeaderSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        self.inner
            .find_plan_header_snapshot_by_plan_id(plan_id)
            .map(map_header)
            .map_err(map_err)
    }

    fn list_rest_plan_field_row_snapshots_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<CultivationPlanRestPlanFieldRowSnapshot>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.inner
            .list_rest_plan_field_row_snapshots_by_plan_id(plan_id)
            .map(|rows| rows.into_iter().map(map_field).collect())
            .map_err(map_err)
    }

    fn list_rest_plan_crop_row_snapshots_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<CultivationPlanRestPlanCropRowSnapshot>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.inner
            .list_rest_plan_crop_row_snapshots_by_plan_id(plan_id)
            .map(|rows| rows.into_iter().map(map_crop).collect())
            .map_err(map_err)
    }

    fn list_rest_plan_cultivation_row_snapshots_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<CultivationPlanRestPlanCultivationRowSnapshot>, Box<dyn std::error::Error + Send + Sync>>
    {
        self.inner
            .list_rest_plan_cultivation_row_snapshots_by_plan_id(plan_id)
            .map(|rows| rows.into_iter().map(map_cultivation).collect())
            .map_err(map_err)
    }

    fn list_palette_crop_ids_by_plan_id(
        &self,
        plan_id: i64,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
        self.inner.list_palette_crop_ids_by_plan_id(plan_id).map_err(map_err)
    }
}
