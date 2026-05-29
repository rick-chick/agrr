//! Ruby: `Domain::CultivationPlan::Mappers::CultivationPlanRestPlanSnapshotMapper`

use crate::cultivation_plan::dtos::rest_plan_snapshots::{
    CultivationPlanRestPlanCropRowSnapshot, CultivationPlanRestPlanCultivationRowSnapshot,
    CultivationPlanRestPlanFieldRowSnapshot, CultivationPlanRestPlanHeaderSnapshot,
    CultivationPlanRestPlanSnapshot,
};
use crate::cultivation_plan::gateways::CultivationPlanRestPlanReadGateway;

pub fn from_snapshots(
    header: CultivationPlanRestPlanHeaderSnapshot,
    field_rows: Vec<CultivationPlanRestPlanFieldRowSnapshot>,
    crop_rows: Vec<CultivationPlanRestPlanCropRowSnapshot>,
    cultivation_rows: Vec<CultivationPlanRestPlanCultivationRowSnapshot>,
    palette_crop_ids: Vec<i64>,
) -> CultivationPlanRestPlanSnapshot {
    CultivationPlanRestPlanSnapshot {
        id: header.id,
        user_id: header.user_id,
        plan_year: header.plan_year,
        plan_name: header.plan_name,
        display_name: header.display_name,
        plan_type: header.plan_type,
        status: header.status,
        total_area: header.total_area,
        planning_start_date: header.planning_start_date,
        planning_end_date: header.planning_end_date,
        calculated_planning_start_date: header.calculated_planning_start_date,
        prediction_target_end_date: header.prediction_target_end_date,
        total_profit: header.total_profit,
        total_revenue: header.total_revenue,
        total_cost: header.total_cost,
        farm_display_name: header.farm_display_name,
        farm_region: header.farm_region,
        field_rows,
        crop_rows,
        cultivation_rows,
        palette_crop_ids,
    }
}

pub fn load_snapshot<G: CultivationPlanRestPlanReadGateway>(
    read_gateway: &G,
    plan_id: i64,
) -> Result<CultivationPlanRestPlanSnapshot, Box<dyn std::error::Error + Send + Sync>> {
    Ok(from_snapshots(
        read_gateway.find_plan_header_snapshot_by_plan_id(plan_id)?,
        read_gateway.list_rest_plan_field_row_snapshots_by_plan_id(plan_id)?,
        read_gateway.list_rest_plan_crop_row_snapshots_by_plan_id(plan_id)?,
        read_gateway.list_rest_plan_cultivation_row_snapshots_by_plan_id(plan_id)?,
        read_gateway.list_palette_crop_ids_by_plan_id(plan_id)?,
    ))
}
