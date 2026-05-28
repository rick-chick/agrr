use crate::shared::policies::crop_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::record_ref::RecordRef;
use crate::shared::reference_record_authorization;
use crate::shared::user::User;

/// Ruby: `Domain::Crop::Policies::CropMastersNestedAccess`
pub fn assert_edit_allowed_for_masters<R: RecordRef>(
    user: User,
    crop_entity: &R,
) -> Result<(), PolicyPermissionDenied> {
    let access_filter = crop_policy::record_access_filter(user);
    reference_record_authorization::assert_edit_allowed(&access_filter, crop_entity)
}
