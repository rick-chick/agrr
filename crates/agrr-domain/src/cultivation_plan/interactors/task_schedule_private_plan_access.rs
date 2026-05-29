//! Ruby: `Domain::CultivationPlan::Interactors::TaskSchedulePrivatePlanAccess`

use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::cultivation_plan::policies::private_cultivation_plan_access_policy;
use crate::shared::exceptions::RecordNotFoundError;

pub fn access_allowed<G: CultivationPlanGateway + ?Sized>(
    plan_gateway: &G,
    plan_id: i64,
    user_id: i64,
) -> bool {
    match plan_gateway.find_by_id(plan_id) {
        Ok(plan) => !private_cultivation_plan_access_policy::access_denied(&plan, user_id),
        Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => false,
        Err(err) => {
            let _ = err;
            false
        }
    }
}

#[cfg(test)]
mod interactors_task_schedule_private_plan_access_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_task_schedule_private_plan_access_test.rs"));
}
