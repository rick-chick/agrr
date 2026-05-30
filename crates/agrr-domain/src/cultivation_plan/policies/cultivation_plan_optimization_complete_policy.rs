//! Ruby: `Domain::CultivationPlan::Policies::CultivationPlanOptimizationCompletePolicy`

/// True when agrr allocate returned at least one field schedule to persist.
pub fn allocation_has_field_schedules(allocation_result: &serde_json::Value) -> bool {
    allocation_result
        .get("field_schedules")
        .and_then(|v| v.as_array())
        .is_some_and(|schedules| !schedules.is_empty())
}

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
mod policies_cultivation_plan_optimization_complete_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/policies_cultivation_plan_optimization_complete_policy_test.rs"));
}
