use std::collections::HashMap;

use crate::field_cultivation::dtos::{
    FieldCultivationSyncExistingFieldCultivationEntry, FieldCultivationSyncPlanCropEntry,
    FieldCultivationSyncPlanSnapshot,
};

pub fn from_snapshots(
    plan_id: i64,
    plan_field_ids: Vec<i64>,
    plan_crop_rows: Vec<FieldCultivationSyncPlanCropEntry>,
    existing_field_cultivation_entries: Vec<FieldCultivationSyncExistingFieldCultivationEntry>,
) -> FieldCultivationSyncPlanSnapshot {
    let plan_fields_by_id = plan_field_ids
        .into_iter()
        .map(|id| (id, id))
        .collect::<HashMap<_, _>>();
    let existing_field_cultivations_by_id = existing_field_cultivation_entries
        .into_iter()
        .map(|entry| (entry.field_cultivation_id, entry))
        .collect();

    FieldCultivationSyncPlanSnapshot {
        plan_id,
        plan_fields_by_id,
        plan_crop_rows,
        existing_field_cultivations_by_id,
    }
}

#[cfg(test)]
mod mappers_field_cultivation_sync_plan_snapshot_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/mappers_field_cultivation_sync_plan_snapshot_mapper_test.rs"));
}
