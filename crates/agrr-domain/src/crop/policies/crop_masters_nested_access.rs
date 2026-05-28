//! Ruby: `Domain::Crop::Policies::CropMastersNestedAccess`

use crate::crop::entities::CropEntity;
use crate::shared::policies::crop_policy;
use crate::shared::reference_record_authorization;
use crate::shared::user::User;

pub fn assert_edit_allowed_for_masters(
    user: &User,
    crop_entity: &CropEntity,
) -> Result<(), crate::shared::policies::policy_permission_denied::PolicyPermissionDenied> {
    let access_filter = crop_policy::record_access_filter(*user);
    reference_record_authorization::assert_edit_allowed(&access_filter, crop_entity)
}
