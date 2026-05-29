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
mod policies_field_access_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field/policies_field_access_test.rs"));
}
