//! Threshold policy for blueprint timing adjustment proposals from plan-vs-actual variance.

/// Minimum absolute average delta days to suggest a BP timing adjustment.
pub const MIN_AVERAGE_DELTA_DAYS: f64 = 1.0;

/// Minimum recorded items required to emit a proposal.
pub const MIN_RECORDED_ITEM_COUNT: i64 = 1;

/// Returns true when category variance is large enough to suggest BP timing adjustment.
pub fn qualifies_for_proposal(average_delta_days: f64, recorded_item_count: i64) -> bool {
    recorded_item_count >= MIN_RECORDED_ITEM_COUNT
        && average_delta_days.abs() >= MIN_AVERAGE_DELTA_DAYS
}

#[cfg(test)]
mod policies_blueprint_timing_adjustment_policy_test_inline {
    use super::*;

    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/policies_blueprint_timing_adjustment_policy_test.rs"
    ));
}
