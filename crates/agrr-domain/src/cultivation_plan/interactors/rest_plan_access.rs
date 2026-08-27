//! Ruby: `Domain::CultivationPlan::Interactors::RestPlanAccess`

use crate::cultivation_plan::dtos::{CultivationPlanRestAuth, CultivationPlanRestAuthMode};
use crate::cultivation_plan::entities::CultivationPlanEntity;
use crate::cultivation_plan::policies::{
    plan_read_authorization, private_cultivation_plan_access_policy,
    public_plan_session_authorization,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RestPlanAccessResult {
    Allowed,
    NotFound,
    Forbidden,
}

pub fn evaluate(plan: &CultivationPlanEntity, auth: &CultivationPlanRestAuth) -> RestPlanAccessResult {
    match auth.mode {
        CultivationPlanRestAuthMode::Private => {
            let user_id = auth.user_id.unwrap_or(-1);
            if private_cultivation_plan_access_policy::access_denied(
                plan,
                user_id,
                &auth.member_organization_ids,
            ) {
                RestPlanAccessResult::NotFound
            } else {
                RestPlanAccessResult::Allowed
            }
        }
        CultivationPlanRestAuthMode::Public => {
            if !plan_read_authorization::public_plan(&plan.plan_type) {
                return RestPlanAccessResult::NotFound;
            }
            if let Some(session) = &auth.public_session_id {
                if !public_plan_session_authorization::session_matches(
                    plan.session_id.as_deref(),
                    session,
                ) {
                    return RestPlanAccessResult::Forbidden;
                }
            }
            RestPlanAccessResult::Allowed
        }
    }
}

pub fn access_denied(plan: &CultivationPlanEntity, auth: &CultivationPlanRestAuth) -> bool {
    evaluate(plan, auth) != RestPlanAccessResult::Allowed
}

#[cfg(test)]
mod interactors_rest_plan_access_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_rest_plan_access_test.rs"));
}
