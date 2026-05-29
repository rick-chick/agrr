//! Ruby: `Domain::Crop::Policies::CropMastersCropEditAccess`

use crate::crop::entities::CropEntity;
use crate::shared::policies::crop_policy::CropRecordAccessPolicy;
use crate::shared::reference_record_access_filter::ReferenceRecordAccessFilter;
use crate::shared::reference_record_authorization;

pub fn assert_edit(
    access_filter: &ReferenceRecordAccessFilter<CropRecordAccessPolicy>,
    crop_entity: &CropEntity,
) -> Result<(), crate::shared::policies::policy_permission_denied::PolicyPermissionDenied> {
    reference_record_authorization::assert_edit_allowed(access_filter, crop_entity)
}

pub fn assert_edit_or_on_failure<F>(
    access_filter: &ReferenceRecordAccessFilter<CropRecordAccessPolicy>,
    crop_entity: &CropEntity,
    on_failure: F,
) -> bool
where
    F: FnOnce(),
{
    match assert_edit(access_filter, crop_entity) {
        Ok(()) => true,
        Err(_) => {
            on_failure();
            false
        }
    }
}

#[cfg(test)]
mod policies_crop_masters_crop_edit_access_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/policies_crop_masters_crop_edit_access_test.rs"));
}
