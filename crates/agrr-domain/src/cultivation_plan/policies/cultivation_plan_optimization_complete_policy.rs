//! Ruby: `Domain::CultivationPlan::Policies::CultivationPlanOptimizationCompletePolicy`

pub fn should_mark_plan_completed(plan_status: &str, field_cultivation_statuses: &[String]) -> bool {
    if plan_status != "optimizing" {
        return false;
    }
    if field_cultivation_statuses.is_empty() {
        return false;
    }
    field_cultivation_statuses
        .iter()
        .all(|s| s == "completed")
}

#[cfg(test)]
mod tests {
    use super::*;

    // Ruby: test "should_mark_plan_completed when optimizing and all field cultivations completed"
    #[test]
    fn should_mark_plan_completed_when_optimizing_and_all_completed() {
        assert!(should_mark_plan_completed(
            "optimizing",
            &["completed".into(), "completed".into()]
        ));
    }

    // Ruby: test "should not mark when not optimizing"
    #[test]
    fn should_not_mark_when_not_optimizing() {
        assert!(!should_mark_plan_completed("completed", &["completed".into()]));
    }

    // Ruby: test "should not mark when field cultivations empty"
    #[test]
    fn should_not_mark_when_field_cultivations_empty() {
        assert!(!should_mark_plan_completed("optimizing", &[]));
    }
}
