// Tests for blueprint amount adjustment policy.

use crate::cultivation_plan::policies::blueprint_amount_adjustment_policy::{
    proposal_progress_key, qualifies_for_proposal, MIN_AVERAGE_AMOUNT_DELTA,
};

#[test]
fn qualifies_when_amount_delta_meets_threshold() {
    assert!(qualifies_for_proposal(MIN_AVERAGE_AMOUNT_DELTA, 1));
    assert!(qualifies_for_proposal(-2.5, 2));
}

#[test]
fn rejects_when_amount_delta_below_threshold() {
    assert!(!qualifies_for_proposal(0.25, 1));
    assert!(!qualifies_for_proposal(-0.4, 3));
}

#[test]
fn rejects_when_no_recorded_items() {
    assert!(!qualifies_for_proposal(5.0, 0));
}

#[test]
fn proposal_progress_key_uses_crop_category_and_task_type() {
    assert_eq!(
        "bp_amount:42:fertilizer:fertilize",
        proposal_progress_key(42, "fertilizer", "fertilize")
    );
}
