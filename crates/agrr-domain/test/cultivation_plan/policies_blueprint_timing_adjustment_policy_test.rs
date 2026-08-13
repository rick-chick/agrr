// Tests for blueprint timing adjustment policy.

use crate::cultivation_plan::policies::blueprint_timing_adjustment_policy::{
    qualifies_for_proposal, MIN_AVERAGE_DELTA_DAYS,
};

#[test]
fn qualifies_when_delta_days_meets_threshold() {
    assert!(qualifies_for_proposal(MIN_AVERAGE_DELTA_DAYS, 1));
    assert!(qualifies_for_proposal(-2.5, 2));
}

#[test]
fn rejects_when_delta_days_below_threshold() {
    assert!(!qualifies_for_proposal(0.5, 1));
    assert!(!qualifies_for_proposal(-0.9, 3));
}

#[test]
fn rejects_when_no_recorded_items() {
    assert!(!qualifies_for_proposal(5.0, 0));
}
