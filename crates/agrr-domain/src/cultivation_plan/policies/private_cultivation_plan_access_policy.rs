//! Ruby: `Domain::CultivationPlan::Policies::PrivateCultivationPlanAccessPolicy`

use crate::cultivation_plan::entities::CultivationPlanEntity;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::user::User;

pub fn access_denied(plan: &CultivationPlanEntity, user_id: i64) -> bool {
    plan.user_id != user_id || !plan.plan_type_private()
}

pub fn assert_private_owned(user: &User, plan: &CultivationPlanEntity) -> Result<(), PolicyPermissionDenied> {
    if access_denied(plan, user.id) {
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
