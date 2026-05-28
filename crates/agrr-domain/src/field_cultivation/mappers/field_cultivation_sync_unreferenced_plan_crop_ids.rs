use crate::field_cultivation::dtos::FieldCultivationSyncPlanSnapshot;

pub fn ids_to_delete(
    plan_snapshot: &FieldCultivationSyncPlanSnapshot,
    referenced_crop_ids: &[String],
) -> Vec<i64> {
    if referenced_crop_ids.is_empty() {
        return vec![];
    }
    let referenced: Vec<String> = referenced_crop_ids.iter().map(|id| id.to_string()).collect();
    let rows = &plan_snapshot.plan_crop_rows;
    let all_ids: Vec<i64> = rows.iter().map(|r| r.plan_crop_id).collect();
    let retained_ids: Vec<i64> = rows
        .iter()
        .filter(|row| referenced.contains(&row.crop_id))
        .map(|row| row.plan_crop_id)
        .collect();
    all_ids
        .into_iter()
        .filter(|id| !retained_ids.contains(id))
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::field_cultivation::dtos::FieldCultivationSyncPlanCropEntry;
    use std::collections::HashMap;

    #[test]
    fn returns_unreferenced_plan_crop_ids() {
        let snapshot = FieldCultivationSyncPlanSnapshot {
            plan_id: 1,
            plan_fields_by_id: HashMap::new(),
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
            existing_field_cultivations_by_id: HashMap::new(),
        };
        assert_eq!(ids_to_delete(&snapshot, &["3".into()]), vec![90]);
    }
}
