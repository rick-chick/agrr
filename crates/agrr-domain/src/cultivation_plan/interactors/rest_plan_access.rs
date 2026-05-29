//! Ruby: `Domain::CultivationPlan::Interactors::RestPlanAccess`

use crate::cultivation_plan::dtos::{CultivationPlanRestAuth, CultivationPlanRestAuthMode};
use crate::cultivation_plan::entities::CultivationPlanEntity;
use crate::cultivation_plan::policies::{
    plan_read_authorization, private_cultivation_plan_access_policy,
};

pub fn access_denied(plan: &CultivationPlanEntity, auth: &CultivationPlanRestAuth) -> bool {
    match auth.mode {
        CultivationPlanRestAuthMode::Private => {
            let user_id = auth.user_id.unwrap_or(-1);
            private_cultivation_plan_access_policy::access_denied(plan, user_id)
        }
        CultivationPlanRestAuthMode::Public => !plan_read_authorization::public_plan(&plan.plan_type),
    }
}

#[cfg(test)]
mod interactors_rest_plan_access_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_rest_plan_access_test.rs"));
}
