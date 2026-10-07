// Tests for field_cultivation_climate_progress_policy.

use serde_json::json;
use time::macros::date;

use crate::field_cultivation::dtos::FieldCultivationClimateFailureReason;
use crate::field_cultivation::policies::validate_progress_result;

#[test]
fn rejects_empty_progress_records() {
    let err = validate_progress_result(
        &json!({ "progress_records": [] }),
        date!(2026 - 03 - 01),
        date!(2026 - 03 - 02),
        2,
    )
    .expect_err("empty progress");
    assert_eq!(
        err.0.reason,
        FieldCultivationClimateFailureReason::ProgressResultInvalid
    );
}

#[test]
fn rejects_missing_cumulative_gdd() {
    let err = validate_progress_result(
        &json!({
            "progress_records": [
                { "date": "2026-03-01", "cumulative_gdd": null }
            ]
        }),
        date!(2026 - 03 - 01),
        date!(2026 - 03 - 02),
        1,
    )
    .expect_err("null gdd");
    assert_eq!(
        err.0.reason,
        FieldCultivationClimateFailureReason::ProgressResultInvalid
    );
}

#[test]
fn rejects_records_outside_cultivation_period() {
    let err = validate_progress_result(
        &json!({
            "progress_records": [
                { "date": "2026-03-10", "cumulative_gdd": 5.0 }
            ]
        }),
        date!(2026 - 03 - 01),
        date!(2026 - 03 - 02),
        0,
    )
    .expect_err("out of period");
    assert_eq!(
        err.0.reason,
        FieldCultivationClimateFailureReason::ProgressResultInvalid
    );
}

#[test]
fn accepts_valid_in_period_records() {
    validate_progress_result(
        &json!({
            "progress_records": [
                { "date": "2026-03-01", "cumulative_gdd": 5.0 },
                { "date": "2026-03-02", "cumulative_gdd": 10.0 }
            ]
        }),
        date!(2026 - 03 - 01),
        date!(2026 - 03 - 02),
        2,
    )
    .expect("valid progress");
}
