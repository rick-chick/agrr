//! Ruby: `Domain::CultivationPlan::Policies::PrivateCultivationPlanAccessPolicy`

use crate::cultivation_plan::entities::CultivationPlanEntity;
use crate::shared::org_scope::organization_member_access;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::user::User;

pub fn access_denied(
    plan: &CultivationPlanEntity,
    user_id: i64,
    member_organization_ids: &[i64],
) -> bool {
    if !plan.plan_type_private() {
        return true;
    }
    if plan.user_id == user_id {
        return false;
    }
    !organization_member_access(
        member_organization_ids,
        false,
        plan.organization_id,
    )
}

pub fn assert_private_owned(
    user: &User,
    plan: &CultivationPlanEntity,
    member_organization_ids: &[i64],
) -> Result<(), PolicyPermissionDenied> {
    if access_denied(plan, user.id, member_organization_ids) {
        Err(PolicyPermissionDenied)
    } else {
        Ok(())
    }
}

#[cfg(test)]
mod policies_private_cultivation_plan_access_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/policies_private_cultivation_plan_access_policy_test.rs"));
}
