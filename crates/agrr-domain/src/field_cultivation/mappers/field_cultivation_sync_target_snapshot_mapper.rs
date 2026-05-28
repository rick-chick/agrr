use serde_json::json;

use crate::field_cultivation::dtos::{
    FieldCultivationSyncCultivationPlanSummary, FieldCultivationSyncDesiredRow,
    FieldCultivationSyncInput, FieldCultivationSyncPlanSnapshot, FieldCultivationSyncTargetSnapshot,
};
use crate::field_cultivation::errors::{
    FieldCultivationSyncReferenceError, SyncReferenceKind,
};
use crate::field_cultivation::mappers::field_cultivation_sync_plan_crop_resolver::resolve_plan_crop_id;

pub fn to_target_snapshot(
    sync_input: &FieldCultivationSyncInput,
    plan_snapshot: &FieldCultivationSyncPlanSnapshot,
) -> Result<FieldCultivationSyncTargetSnapshot, FieldCultivationSyncReferenceError> {
    let mut referenced_crop_ids: Vec<String> = Vec::new();
    let mut field_cultivation_rows: Vec<FieldCultivationSyncDesiredRow> = Vec::new();

    for field_schedule in &sync_input.field_schedules {
        let Some(field_id) = field_schedule.field_id else {
            continue;
        };
        let Some(plan_field_id) = plan_snapshot.plan_fields_by_id.get(&field_id).copied() else {
            return Err(FieldCultivationSyncReferenceError::new(
                SyncReferenceKind::FieldMissing,
                "plan field missing",
                Some(field_id),
                None,
                None,
                None,
            ));
        };

        if field_schedule.allocations.is_empty() {
            continue;
        }

        for allocation in &field_schedule.allocations {
            referenced_crop_ids.push(allocation.crop_id.clone());

            let Some(plan_crop_id) = resolve_plan_crop_id(plan_snapshot, allocation)? else {
                return Err(FieldCultivationSyncReferenceError::new(
                    SyncReferenceKind::PlanCropMissing,
                    "plan crop missing",
                    None,
                    Some(allocation.crop_id.clone()),
                    None,
                    None,
                ));
            };

            let allocation_id_raw = allocation.resolved_allocation_raw();
            let field_cultivation_id = allocation_id_raw.as_ref().and_then(|raw| raw.parse().ok());

            let start_date = allocation.start_date;
            let completion_date = allocation.completion_date;
            let cultivation_days = (completion_date - start_date).whole_days() as i32 + 1;

            field_cultivation_rows.push(FieldCultivationSyncDesiredRow {
                field_cultivation_id,
                cultivation_plan_field_id: plan_field_id,
                cultivation_plan_crop_id: plan_crop_id,
                start_date,
                completion_date,
                cultivation_days,
                area: allocation.area_used.or(allocation.area),
                estimated_cost: allocation.total_cost.or(allocation.cost),
                optimization_result: json!({
                    "revenue": allocation.expected_revenue.or(allocation.revenue),
                    "profit": allocation.profit,
                    "accumulated_gdd": allocation.accumulated_gdd,
                }),
            });
        }
    }

    referenced_crop_ids.sort();
    referenced_crop_ids.dedup();

    Ok(FieldCultivationSyncTargetSnapshot {
        field_cultivation_rows,
        cultivation_plan_summary: FieldCultivationSyncCultivationPlanSummary {
            optimization_summary: sync_input.optimization_summary.clone(),
            total_profit: sync_input.total_profit,
            total_revenue: sync_input.total_revenue,
            total_cost: sync_input.total_cost,
            optimization_time: sync_input.optimization_time,
            algorithm_used: sync_input.algorithm_used.clone(),
            is_optimal: sync_input.is_optimal,
        },
        referenced_crop_ids,
    })
}
