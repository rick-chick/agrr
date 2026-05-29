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
mod mappers_field_cultivation_sync_unreferenced_plan_crop_ids_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/mappers_field_cultivation_sync_unreferenced_plan_crop_ids_test.rs"));
}
