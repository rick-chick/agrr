// Tests for blueprint amount adjustment policy.

use crate::cultivation_plan::policies::blueprint_amount_adjustment_policy::{
    proposal_progress_key, qualifies_for_proposal,
};
use crate::cultivation_plan::policies::plan_variance_threshold_policy::{
    FERTILIZER_AMOUNT_DELTA_THRESHOLD, PEST_CONTROL_AMOUNT_DELTA_THRESHOLD,
};

#[test]
fn qualifies_when_fertilizer_amount_delta_meets_category_threshold() {
    assert!(qualifies_for_proposal(FERTILIZER_AMOUNT_DELTA_THRESHOLD, 1, "fertilizer"));
    assert!(qualifies_for_proposal(-2.5, 2, "fertilizer"));
}

#[test]
fn rejects_when_fertilizer_amount_delta_below_category_threshold() {
    assert!(!qualifies_for_proposal(0.25, 1, "fertilizer"));
    assert!(!qualifies_for_proposal(-0.4, 3, "fertilizer"));
}

#[test]
fn qualifies_when_pest_control_amount_delta_meets_lower_category_threshold() {
    assert!(qualifies_for_proposal(PEST_CONTROL_AMOUNT_DELTA_THRESHOLD, 1, "pest_control"));
    assert!(!qualifies_for_proposal(
        PEST_CONTROL_AMOUNT_DELTA_THRESHOLD - 0.01,
        1,
        "pest_control"
    ));
}

#[test]
fn pest_control_qualifies_below_fertilizer_threshold_when_above_pest_threshold() {
    let between_thresholds = PEST_CONTROL_AMOUNT_DELTA_THRESHOLD + 0.01;
    assert!(between_thresholds < FERTILIZER_AMOUNT_DELTA_THRESHOLD);
    assert!(!qualifies_for_proposal(between_thresholds, 1, "fertilizer"));
    assert!(qualifies_for_proposal(between_thresholds, 1, "pest_control"));
}

#[test]
fn rejects_when_no_recorded_items() {
    assert!(!qualifies_for_proposal(5.0, 0, "fertilizer"));
}

#[test]
fn proposal_progress_key_uses_crop_category_and_task_type() {
    assert_eq!(
        "bp_amount:42:fertilizer:fertilize",
        proposal_progress_key(42, "fertilizer", "fertilize")
    );
}
