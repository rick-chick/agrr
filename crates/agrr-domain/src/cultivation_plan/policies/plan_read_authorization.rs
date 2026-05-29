//! Ruby: `Domain::CultivationPlan::Policies::PlanReadAuthorization`

pub fn public_plan(plan_type: &str) -> bool {
    plan_type == "public"
}

#[cfg(test)]
mod policies_plan_read_authorization_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/policies_plan_read_authorization_test.rs"));
}
