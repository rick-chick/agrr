//! Accept incomplete gap-fill API responses when the existing store is training-ready.

use time::Date;

use super::MINIMUM_TRAINING_DAYS;

pub(crate) struct IncompleteGapFillContinuePolicy;

impl IncompleteGapFillContinuePolicy {
    /// Continue with the existing weather store after an incomplete gap-fill fetch.
    pub(crate) fn should_continue(
        latest_date: Option<Date>,
        end_date: Date,
        baseline_count: i64,
    ) -> bool {
        if !latest_date.is_some_and(|latest| latest < end_date) {
            return false;
        }
        baseline_count >= MINIMUM_TRAINING_DAYS
    }
}

#[cfg(test)]
mod policies_incomplete_gap_fill_continue_policy_test_inline {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/weather_data/policies_incomplete_gap_fill_continue_policy_test.rs"
    ));
}
