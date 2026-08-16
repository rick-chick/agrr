//! Threshold policy for blueprint amount adjustment proposals from plan-vs-actual variance.

use crate::cultivation_plan::policies::plan_variance_threshold_policy::amount_delta_threshold_for_category;

/// Minimum recorded items required to emit a proposal.
pub const MIN_RECORDED_ITEM_COUNT: i64 = 1;

/// Proposal progress keys use the format `bp_amount:{crop_id}:{category}:{task_type}:{stage_order}`.
/// When `stage_order` is absent, the segment is `null` (aligned with frontend `bpAmountProposalProgressKey`).
pub fn proposal_progress_key(
    crop_id: i64,
    category: &str,
    task_type: &str,
    stage_order: Option<i32>,
) -> String {
    let stage_segment = stage_order
        .map(|order| order.to_string())
        .unwrap_or_else(|| "null".to_string());
    format!(
        "bp_amount:{}:{}:{}:{}",
        crop_id, category, task_type, stage_segment
    )
}

/// Returns true when amount variance is large enough to suggest BP amount adjustment.
pub fn qualifies_for_proposal(
    average_amount_delta: f64,
    recorded_item_count: i64,
    category: &str,
) -> bool {
    recorded_item_count >= MIN_RECORDED_ITEM_COUNT
        && average_amount_delta.abs() >= amount_delta_threshold_for_category(category)
}

#[cfg(test)]
mod policies_blueprint_amount_adjustment_policy_test_inline {
    use super::*;

    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/policies_blueprint_amount_adjustment_policy_test.rs"
    ));
}
