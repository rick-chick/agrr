//! Ruby: `Domain::CultivationPlan::Mappers::OptimizationPlanReadSnapshotMapper`

use crate::cultivation_plan::dtos::OptimizationPlanSnapshot;
use crate::cultivation_plan::gateways::OptimizationPlanReadGateway;
use crate::cultivation_plan::mappers::optimization_plan_snapshot_mapper::to_snapshot;

pub fn load_snapshot(
    read_gateway: &dyn OptimizationPlanReadGateway,
    plan_id: i64,
) -> Result<OptimizationPlanSnapshot, Box<dyn std::error::Error + Send + Sync>> {
    let core = read_gateway.find_optimization_plan_core_snapshot_by_plan_id(plan_id)?;
    let weather_location = read_gateway.find_optimization_weather_location_by_plan_id(plan_id)?;
    let plan_metadata = read_gateway.find_optimization_plan_metadata_by_plan_id(plan_id)?;

    Ok(to_snapshot(
        core.plan_id,
        core.plan_type_private,
        core.calculated_planning_start_date,
        core.calculated_planning_end_date,
        core.prediction_target_end_date,
        plan_metadata.or(core.plan_metadata),
        core.total_area,
        core.weather_location_present,
        weather_location,
    ))
}
