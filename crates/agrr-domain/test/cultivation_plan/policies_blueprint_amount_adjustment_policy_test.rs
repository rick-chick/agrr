// Tests for blueprint amount adjustment policy.

use crate::cultivation_plan::policies::blueprint_amount_adjustment_policy::{
    proposal_progress_key, qualifies_for_proposal,
};
use crate::cultivation_plan::policies::plan_variance_learning_proposal_progress_policy::validate_proposal_application_progress_updates;
use crate::cultivation_plan::policies::plan_variance_threshold_policy::{
    amount_delta_threshold_for_category, FERTILIZER_AMOUNT_DELTA_THRESHOLD,
    PEST_CONTROL_AMOUNT_DELTA_THRESHOLD,
};

#[test]
fn qualifies_when_amount_delta_meets_category_threshold() {
    assert!(qualifies_for_proposal(
        FERTILIZER_AMOUNT_DELTA_THRESHOLD,
        1,
        "fertilizer"
    ));
    assert!(qualifies_for_proposal(-2.5, 2, "fertilizer"));
    assert!(qualifies_for_proposal(
        PEST_CONTROL_AMOUNT_DELTA_THRESHOLD,
        1,
        "pest_control"
    ));
}

#[test]
fn rejects_when_amount_delta_below_category_threshold() {
    assert!(!qualifies_for_proposal(0.25, 1, "fertilizer"));
    assert!(!qualifies_for_proposal(-0.4, 3, "fertilizer"));
    assert!(!qualifies_for_proposal(0.15, 1, "pest_control"));
}

#[test]
fn pest_control_qualifies_below_fertilizer_threshold() {
    let mid_delta = 0.35;
    assert!(
        mid_delta >= amount_delta_threshold_for_category("pest_control")
            && mid_delta < amount_delta_threshold_for_category("fertilizer")
    );
    assert!(qualifies_for_proposal(mid_delta, 1, "pest_control"));
    assert!(!qualifies_for_proposal(mid_delta, 1, "fertilizer"));
}

#[test]
fn rejects_when_no_recorded_items() {
    assert!(!qualifies_for_proposal(5.0, 0, "fertilizer"));
}

#[test]
fn proposal_progress_key_includes_stage_order() {
    assert_eq!(
        "bp_amount:42:fertilizer:fertilize:1",
        proposal_progress_key(42, "fertilizer", "fertilize", Some(1))
    );
}

#[test]
fn proposal_progress_key_uses_null_segment_when_stage_order_missing() {
    assert_eq!(
        "bp_amount:42:fertilizer:fertilize:null",
        proposal_progress_key(42, "fertilizer", "fertilize", None)
    );
}

#[test]
fn proposal_progress_keys_coexist_in_variance_learning_snapshot() {
    use std::collections::BTreeMap;

    let key_stage_one =
        proposal_progress_key(42, "fertilizer", "fertilize", Some(1));
    let key_stage_two =
        proposal_progress_key(42, "fertilizer", "fertilize", Some(2));

    let mut progress = BTreeMap::new();
    progress.insert(key_stage_one.clone(), "confirmed".into());
    progress.insert(key_stage_two.clone(), "dismissed".into());

    assert_eq!(Some(&"confirmed".to_string()), progress.get(&key_stage_one));
    assert_eq!(Some(&"dismissed".to_string()), progress.get(&key_stage_two));
    assert!(validate_proposal_application_progress_updates(&progress).is_ok());
}
