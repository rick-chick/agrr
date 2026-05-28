//! Ruby: `Domain::Crop::Policies::CropReferenceRecordPolicy`

use crate::shared::record_ref::RecordRef;

pub fn reference_crop<R: RecordRef>(record: &R) -> bool {
    record.is_reference()
}

pub fn region_matches(region: Option<&str>, record_region: Option<&str>) -> bool {
    match region {
        None | Some("") => true,
        Some(r) => record_region.unwrap_or("") == r,
    }
}

pub fn visible_for_public_plan_add_crop<R: RecordRef>(record: &R) -> bool {
    reference_crop(record)
}

pub fn visible_for_entry_schedule<R: RecordRef>(
    record: &R,
    region: Option<&str>,
    record_region: Option<&str>,
) -> bool {
    reference_crop(record) && region_matches(region, record_region)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::crop::entities::CropEntity;
    use crate::shared::record_ref::RecordStub;

    // Ruby: test "visible_for_public_plan_add_crop? requires reference crop"
    #[test]
    fn visible_for_public_plan_requires_reference() {
        let reference = RecordStub {
            is_reference: true,
            user_id: None,
        };
        let owned = RecordStub {
            is_reference: false,
            user_id: Some(1),
        };
        assert!(visible_for_public_plan_add_crop(&reference));
        assert!(!visible_for_public_plan_add_crop(&owned));
    }

    // Ruby: test "visible_for_entry_schedule? requires reference and region match"
    #[test]
    fn visible_for_entry_schedule_requires_reference_and_region() {
        let crop = CropEntity {
            id: 1,
            user_id: None,
            name: "Tomato".into(),
            variety: None,
            is_reference: true,
            area_per_unit: None,
            revenue_per_area: None,
            region: Some("jp".into()),
            groups: vec![],
            created_at: None,
            updated_at: None,
        };
        assert!(visible_for_entry_schedule(
            &crop,
            Some("jp"),
            crop.region.as_deref()
        ));
        assert!(!visible_for_entry_schedule(
            &crop,
            Some("us"),
            crop.region.as_deref()
        ));
    }
}
