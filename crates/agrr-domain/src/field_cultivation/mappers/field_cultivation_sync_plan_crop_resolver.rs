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
mod tests {
    use super::*;
    use crate::field_cultivation::dtos::{
        FieldCultivationSyncExistingFieldCultivationEntry, FieldCultivationSyncPlanCropEntry,
    };
    use std::collections::HashMap;
    use time::macros::date;

    fn allocation(crop_id: &str, allocation_id: Option<i64>) -> FieldCultivationSyncAllocationInput {
        FieldCultivationSyncAllocationInput {
            allocation_id,
            external_allocation_id: None,
            crop_id: crop_id.into(),
            start_date: date!(2026 - 01 - 01),
            completion_date: date!(2026 - 01 - 02),
            area_used: None,
            area: None,
            total_cost: None,
            cost: None,
            expected_revenue: None,
            revenue: None,
            profit: None,
            accumulated_gdd: None,
        }
    }

    #[test]
    fn resolves_existing_field_cultivation_via_allocation_id() {
        let mut existing = HashMap::new();
        existing.insert(
            9,
            FieldCultivationSyncExistingFieldCultivationEntry {
                field_cultivation_id: 9,
                cultivation_plan_crop_id: 30,
                crop_id: "3".into(),
            },
        );
        let snapshot = FieldCultivationSyncPlanSnapshot {
            plan_id: 1,
            plan_fields_by_id: HashMap::new(),
            plan_crop_rows: vec![],
            existing_field_cultivations_by_id: existing,
        };
        let id = resolve_plan_crop_id(&snapshot, &allocation("3", Some(9))).unwrap();
        assert_eq!(id, Some(30));
    }

    #[test]
    fn resolves_unique_crop_id_match() {
        let snapshot = FieldCultivationSyncPlanSnapshot {
            plan_id: 1,
            plan_fields_by_id: HashMap::new(),
            plan_crop_rows: vec![FieldCultivationSyncPlanCropEntry {
                plan_crop_id: 30,
                crop_id: "3".into(),
            }],
            existing_field_cultivations_by_id: HashMap::new(),
        };
        let id = resolve_plan_crop_id(&snapshot, &allocation("3", None)).unwrap();
        assert_eq!(id, Some(30));
    }
}
