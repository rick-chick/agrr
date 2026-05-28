use crate::field::results::FarmRecord;
use crate::shared::policies::farm_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::reference_record_authorization;
use crate::shared::user::User;

/// Ruby: `Domain::Field::Policies::FieldAccess`
pub fn assert_farm_fields_list_allowed(user: &User, farm: &FarmRecord) -> Result<(), PolicyPermissionDenied> {
    let allowed = user.admin || farm.user_id == Some(user.id);
    if allowed {
        Ok(())
    } else {
        Err(PolicyPermissionDenied)
    }
}

pub fn assert_field_edit_on_farm_allowed(
    user: &User,
    farm: &FarmRecord,
) -> Result<(), PolicyPermissionDenied> {
    let access_filter = farm_policy::record_access_filter(*user);
    reference_record_authorization::assert_edit_allowed(&access_filter, farm)
}

pub fn assert_owned(user: &User, farm: &FarmRecord) -> Result<(), PolicyPermissionDenied> {
    let allowed = user.admin || farm.user_id == Some(user.id);
    if allowed {
        Ok(())
    } else {
        Err(PolicyPermissionDenied)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::field::results::FarmRecord;
    use crate::shared::user::User;

    fn farm_entity(user_id: i64) -> FarmRecord {
        FarmRecord {
            id: 1,
            name: "F".into(),
            user_id: Some(user_id),
            is_reference: false,
            latitude: Some(35.0),
            longitude: Some(135.0),
            region: Some("jp".into()),
            created_at: Some("2024-01-01T00:00:00Z".into()),
            updated_at: Some("2024-01-01T00:00:00Z".into()),
        }
    }

    fn farm_stub(user_id: i64, is_reference: bool) -> FarmRecord {
        FarmRecord {
            id: 1,
            name: "F".into(),
            user_id: Some(user_id),
            is_reference,
            latitude: None,
            longitude: None,
            region: None,
            created_at: None,
            updated_at: None,
        }
    }

    // Ruby: test "assert_owned! passes for farm owner"
    #[test]
    fn assert_owned_passes_for_farm_owner() {
        let user = User::new(10, false);
        assert!(assert_owned(&user, &farm_entity(10)).is_ok());
    }

    // Ruby: test "assert_owned! allows admin"
    #[test]
    fn assert_owned_allows_admin() {
        let user = User::new(99, true);
        assert!(assert_owned(&user, &farm_entity(1)).is_ok());
    }

    // Ruby: test "assert_owned! raises PolicyPermissionDenied for non-owner non-admin"
    #[test]
    fn assert_owned_denies_non_owner_non_admin() {
        let user = User::new(1, false);
        assert_eq!(
            assert_owned(&user, &farm_entity(2)),
            Err(PolicyPermissionDenied)
        );
    }

    // Ruby: test "assert_farm_fields_list_allowed! passes for farm owner"
    #[test]
    fn assert_farm_fields_list_allowed_passes_for_owner() {
        let user = User::new(10, false);
        assert!(assert_farm_fields_list_allowed(&user, &farm_stub(10, false)).is_ok());
    }

    // Ruby: test "assert_farm_fields_list_allowed! raises for other users farm"
    #[test]
    fn assert_farm_fields_list_allowed_denies_other_users_farm() {
        let user = User::new(1, false);
        assert_eq!(
            assert_farm_fields_list_allowed(&user, &farm_stub(2, false)),
            Err(PolicyPermissionDenied)
        );
    }
}
