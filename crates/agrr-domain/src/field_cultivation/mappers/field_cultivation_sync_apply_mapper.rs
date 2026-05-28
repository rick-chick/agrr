use crate::field_cultivation::dtos::{
    FieldCultivationSyncApply, FieldCultivationSyncPlanSnapshot, FieldCultivationSyncTargetSnapshot,
};
use crate::field_cultivation::mappers::field_cultivation_sync_unreferenced_plan_crop_ids::ids_to_delete;

pub fn to_apply(
    plan_snapshot: &FieldCultivationSyncPlanSnapshot,
    target_snapshot: &FieldCultivationSyncTargetSnapshot,
) -> FieldCultivationSyncApply {
    let existing_ids = plan_snapshot.existing_field_cultivation_ids();
    let desired_rows = &target_snapshot.field_cultivation_rows;

    let field_cultivations_to_update: Vec<_> = desired_rows
        .iter()
        .filter(|row| {
            row.field_cultivation_id
                .is_some_and(|id| existing_ids.contains(&id))
        })
        .cloned()
        .collect();

    let field_cultivations_to_create: Vec<_> = desired_rows
        .iter()
        .filter(|row| {
            !row.field_cultivation_id
                .is_some_and(|id| existing_ids.contains(&id))
        })
        .cloned()
        .collect();

    let retained_ids: Vec<i64> = field_cultivations_to_update
        .iter()
        .filter_map(|row| row.field_cultivation_id)
        .collect();
    let field_cultivation_ids_to_delete: Vec<i64> = existing_ids
        .into_iter()
        .filter(|id| !retained_ids.contains(id))
        .collect();

    let cultivation_plan_crop_ids_to_delete =
        ids_to_delete(plan_snapshot, &target_snapshot.referenced_crop_ids);

    FieldCultivationSyncApply {
        field_cultivations_to_update,
        field_cultivations_to_create,
        field_cultivation_ids_to_delete,
        cultivation_plan_crop_ids_to_delete,
        cultivation_plan_summary: target_snapshot.cultivation_plan_summary.clone(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::field_cultivation::dtos::{
        FieldCultivationSyncAllocationInput, FieldCultivationSyncExistingFieldCultivationEntry,
        FieldCultivationSyncFieldScheduleInput, FieldCultivationSyncInput,
        FieldCultivationSyncPlanCropEntry, FieldCultivationSyncPlanSnapshot,
    };
    use crate::field_cultivation::mappers::field_cultivation_sync_target_snapshot_mapper::to_target_snapshot;
    use std::collections::HashMap;
    use time::macros::date;

    #[test]
    fn builds_apply_with_diff_and_unreferenced_plan_crop_ids() {
        let allocation = FieldCultivationSyncAllocationInput {
            allocation_id: Some(9),
            external_allocation_id: None,
            crop_id: "3".into(),
            start_date: date!(2026 - 03 - 01),
            completion_date: date!(2026 - 03 - 10),
            area_used: None,
            area: None,
            total_cost: None,
            cost: None,
            expected_revenue: None,
            revenue: None,
            profit: None,
            accumulated_gdd: None,
        };
        let sync_input = FieldCultivationSyncInput {
            field_schedules: vec![FieldCultivationSyncFieldScheduleInput {
                field_id: Some(2),
                allocations: vec![allocation],
            }],
            optimization_summary: None,
            total_profit: Some(1.0),
            total_revenue: None,
            total_cost: None,
            optimization_time: None,
            algorithm_used: None,
            is_optimal: None,
        };
        let mut existing = HashMap::new();
        existing.insert(
            9,
            FieldCultivationSyncExistingFieldCultivationEntry {
                field_cultivation_id: 9,
                cultivation_plan_crop_id: 30,
                crop_id: "3".into(),
            },
        );
        existing.insert(
            99,
            FieldCultivationSyncExistingFieldCultivationEntry {
                field_cultivation_id: 99,
                cultivation_plan_crop_id: 90,
                crop_id: "9".into(),
            },
        );
        let plan_snapshot = FieldCultivationSyncPlanSnapshot {
            plan_id: 1,
            plan_fields_by_id: HashMap::from([(2, 20)]),
            plan_crop_rows: vec![
                FieldCultivationSyncPlanCropEntry {
                    plan_crop_id: 30,
                    crop_id: "3".into(),
                },
                FieldCultivationSyncPlanCropEntry {
                    plan_crop_id: 90,
                    crop_id: "9".into(),
                },
            ],
            existing_field_cultivations_by_id: existing,
        };
        let target_snapshot = to_target_snapshot(&sync_input, &plan_snapshot).unwrap();
        let sync_apply = to_apply(&plan_snapshot, &target_snapshot);
        assert_eq!(sync_apply.field_cultivations_to_update.len(), 1);
        assert!(sync_apply.field_cultivations_to_create.is_empty());
        assert_eq!(sync_apply.field_cultivation_ids_to_delete, vec![99]);
        assert_eq!(sync_apply.cultivation_plan_crop_ids_to_delete, vec![90]);
    }
}
