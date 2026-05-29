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
mod tests {
    use super::*;
    use crate::field_cultivation::dtos::FieldCultivationSyncPlanCropEntry;

    #[test]
    fn from_snapshots_builds_plan_fields_map() {
        let snapshot = from_snapshots(
            1,
            vec![2, 20],
            vec![FieldCultivationSyncPlanCropEntry {
                plan_crop_id: 30,
                crop_id: "3".into(),
            }],
            vec![FieldCultivationSyncExistingFieldCultivationEntry {
                field_cultivation_id: 9,
                cultivation_plan_crop_id: 30,
                crop_id: "3".into(),
            }],
        );

        assert_eq!(snapshot.plan_id, 1);
        assert_eq!(snapshot.plan_fields_by_id.get(&2), Some(&2));
        assert!(snapshot.existing_field_cultivation_ids().contains(&9));
    }
}
