//! Threshold policy for blueprint amount adjustment proposals from plan-vs-actual variance.

use crate::cultivation_plan::policies::plan_variance_threshold_policy::DEFAULT_AMOUNT_DELTA_THRESHOLD;

/// Minimum absolute average amount delta to suggest a BP amount adjustment.
pub const MIN_AVERAGE_AMOUNT_DELTA: f64 = DEFAULT_AMOUNT_DELTA_THRESHOLD;

/// Minimum recorded items required to emit a proposal.
pub const MIN_RECORDED_ITEM_COUNT: i64 = 1;

/// Proposal progress keys use the format `bp_amount:{crop_id}:{category}:{task_type}`.
pub fn proposal_progress_key(crop_id: i64, category: &str, task_type: &str) -> String {
    format!("bp_amount:{}:{}:{}", crop_id, category, task_type)
}

/// Returns true when amount variance is large enough to suggest BP amount adjustment.
pub fn qualifies_for_proposal(average_amount_delta: f64, recorded_item_count: i64) -> bool {
    recorded_item_count >= MIN_RECORDED_ITEM_COUNT
        && average_amount_delta.abs() >= MIN_AVERAGE_AMOUNT_DELTA
}

#[cfg(test)]
mod policies_blueprint_amount_adjustment_policy_test_inline {
    use super::*;

    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/policies_blueprint_amount_adjustment_policy_test.rs"
    ));
}
