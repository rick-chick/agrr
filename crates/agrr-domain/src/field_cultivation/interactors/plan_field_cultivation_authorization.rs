use crate::field_cultivation::dtos::FieldCultivationPlanAccessSnapshot;
use crate::field_cultivation::policies::{assert_edit_allowed, assert_view_allowed};
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::user::User;

pub fn assert_field_cultivation_plan_access(
    user: &User,
    access_snapshot: &FieldCultivationPlanAccessSnapshot,
    for_edit: bool,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if for_edit {
        assert_edit_allowed(user, access_snapshot)?;
    } else {
        assert_view_allowed(user, access_snapshot)?;
    }
    Ok(())
}

pub fn assert_public_field_cultivation_plan_access(
    access_snapshot: &FieldCultivationPlanAccessSnapshot,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    if access_snapshot.plan_type_public() {
        Ok(())
    } else {
        Err(Box::new(PolicyPermissionDenied))
    }
}
