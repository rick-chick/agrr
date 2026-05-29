//! Ruby: `Domain::FieldCultivation::Policies::PlanFieldCultivationAccess`

use crate::field_cultivation::dtos::FieldCultivationPlanAccessSnapshot;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::user::User;

pub fn view_allowed(user: &User, context: &FieldCultivationPlanAccessSnapshot) -> bool {
    if context.plan_type_public() {
        return true;
    }
    user.admin || (context.plan_type_private() && context.plan_user_id == Some(user.id))
}

pub fn assert_view_allowed(
    user: &User,
    context: &FieldCultivationPlanAccessSnapshot,
) -> Result<(), PolicyPermissionDenied> {
    if view_allowed(user, context) {
        Ok(())
    } else {
        Err(PolicyPermissionDenied)
    }
}

pub fn assert_edit_allowed(
    user: &User,
    context: &FieldCultivationPlanAccessSnapshot,
) -> Result<(), PolicyPermissionDenied> {
    assert_view_allowed(user, context)
}

#[cfg(test)]
mod policies_plan_field_cultivation_access_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/policies_plan_field_cultivation_access_test.rs"));
}
