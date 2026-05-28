//! Ruby: `Domain::CultivationPlan::Policies::PlanReadAuthorization`

pub fn public_plan(plan_type: &str) -> bool {
    plan_type == "public"
}

#[cfg(test)]
mod tests {
    use super::*;

    // Ruby: test "public_plan? matches plan_type public string"
    #[test]
    fn public_plan_matches_plan_type_public_string() {
        assert!(public_plan("public"));
        assert!(!public_plan("private"));
    }
}
