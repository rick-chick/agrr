// Tests for `policies/incomplete_gap_fill_continue_policy.rs`.

use crate::weather_data::policies::incomplete_gap_fill_continue_policy::IncompleteGapFillContinuePolicy;
use crate::weather_data::policies::MINIMUM_TRAINING_DAYS;
use time::{Date, Month};

#[test]
fn rejects_when_latest_date_is_missing() {
    let end_date = Date::from_calendar_date(2026, Month::September, 6).expect("valid");
    assert!(!IncompleteGapFillContinuePolicy::should_continue(
        None,
        end_date,
        MINIMUM_TRAINING_DAYS,
    ));
}

#[test]
fn rejects_when_store_already_covers_block_end() {
    let end_date = Date::from_calendar_date(2026, Month::September, 6).expect("valid");
    let latest = Date::from_calendar_date(2026, Month::September, 6).expect("valid");
    assert!(!IncompleteGapFillContinuePolicy::should_continue(
        Some(latest),
        end_date,
        MINIMUM_TRAINING_DAYS,
    ));
}

#[test]
fn rejects_when_baseline_store_is_insufficient() {
    let end_date = Date::from_calendar_date(2026, Month::September, 6).expect("valid");
    let latest = Date::from_calendar_date(2026, Month::July, 4).expect("valid");
    assert!(!IncompleteGapFillContinuePolicy::should_continue(
        Some(latest),
        end_date,
        MINIMUM_TRAINING_DAYS - 1,
    ));
}

#[test]
fn accepts_incomplete_gap_fill_when_baseline_store_is_sufficient() {
    let end_date = Date::from_calendar_date(2026, Month::September, 6).expect("valid");
    let latest = Date::from_calendar_date(2026, Month::July, 4).expect("valid");
    assert!(IncompleteGapFillContinuePolicy::should_continue(
        Some(latest),
        end_date,
        MINIMUM_TRAINING_DAYS,
    ));
}
