use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::record_ref::RecordRef;
use crate::shared::user::User;

/// Ruby: `Domain::Shared::Policies::CropNestedPestsAccess`
///
/// Reference crops: any user. Non-reference: owner only (admin cross-user view denied).
pub fn assert_allowed<R: RecordRef>(
    user: &User,
    crop: &R,
) -> Result<(), PolicyPermissionDenied> {
    if crop.is_reference() || crop.user_id() == Some(user.id) {
        Ok(())
    } else {
        Err(PolicyPermissionDenied)
    }
}

#[cfg(test)]
mod policies_crop_nested_pests_access_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/policies_crop_nested_pests_access_test.rs"));
}
