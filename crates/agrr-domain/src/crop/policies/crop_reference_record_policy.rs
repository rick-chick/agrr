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
mod policies_crop_reference_record_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/policies_crop_reference_record_policy_test.rs"));
}
