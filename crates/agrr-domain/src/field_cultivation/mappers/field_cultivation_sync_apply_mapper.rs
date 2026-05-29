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
mod mappers_field_cultivation_sync_apply_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/mappers_field_cultivation_sync_apply_mapper_test.rs"));
}
