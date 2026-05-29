use crate::field_cultivation::dtos::{
    FieldCultivationSyncAllocationInput, FieldCultivationSyncPlanSnapshot,
};
use crate::field_cultivation::errors::{
    FieldCultivationSyncReferenceError, SyncReferenceKind,
};

pub fn resolve_plan_crop_id(
    plan_snapshot: &FieldCultivationSyncPlanSnapshot,
    allocation: &FieldCultivationSyncAllocationInput,
) -> Result<Option<i64>, FieldCultivationSyncReferenceError> {
    if let Some(field_cultivation_id) = allocation.allocation_id {
        let existing = plan_snapshot
            .existing_field_cultivations_by_id
            .get(&field_cultivation_id);
        return Ok(existing.map(|e| e.cultivation_plan_crop_id));
    }

    let crop_id = allocation.crop_id.clone();
    let matches: Vec<_> = plan_snapshot
        .plan_crop_rows
        .iter()
        .filter(|row| row.crop_id == crop_id)
        .collect();
    match matches.len() {
        0 => Ok(None),
        1 => Ok(Some(matches[0].plan_crop_id)),
        _ => Err(FieldCultivationSyncReferenceError::new(
            SyncReferenceKind::PlanCropAmbiguous,
            "multiple plan crops for crop_id",
            None,
            Some(crop_id),
            allocation.resolved_allocation_raw(),
            None,
        )),
    }
}

#[cfg(test)]
mod mappers_field_cultivation_sync_plan_crop_resolver_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/mappers_field_cultivation_sync_plan_crop_resolver_test.rs"));
}
