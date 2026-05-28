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
mod tests {
    use super::*;
    use crate::shared::record_ref::RecordStub;
    use crate::shared::user::User;

    #[test]
    fn assert_allowed_passes_for_reference_crop() {
        let user = User::new(1, true);
        let crop = RecordStub {
            is_reference: true,
            user_id: Some(99),
        };
        assert!(assert_allowed(&user, &crop).is_ok());
    }

    #[test]
    fn assert_allowed_passes_for_crop_owner() {
        let user = User::new(1, false);
        let crop = RecordStub {
            is_reference: false,
            user_id: Some(1),
        };
        assert!(assert_allowed(&user, &crop).is_ok());
    }

    #[test]
    fn assert_allowed_denies_admin_on_another_users_non_reference_crop() {
        let user = User::new(1, true);
        let crop = RecordStub {
            is_reference: false,
            user_id: Some(99),
        };
        assert_eq!(assert_allowed(&user, &crop), Err(PolicyPermissionDenied));
    }
}
