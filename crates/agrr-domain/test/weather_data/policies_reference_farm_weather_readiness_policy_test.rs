// Tests for `policies/reference_farm_weather_readiness_policy.rs`.

use crate::weather_data::policies::reference_farm_weather_readiness_policy::{
    ReferenceFarmWeatherReadinessError, ReferenceFarmWeatherReadinessPolicy,
    MINIMUM_TRAINING_DAYS,
};
use time::{Date, Month};

#[test]
fn validate_rejects_missing_latest() {
    assert_eq!(
        ReferenceFarmWeatherReadinessPolicy::validate(Some(1), None, 10_000),
        Err(ReferenceFarmWeatherReadinessError::NotBackfilled)
    );
}

#[test]
fn validate_rejects_insufficient_historical() {
    assert_eq!(
        ReferenceFarmWeatherReadinessPolicy::validate(
            Some(1),
            Some(Date::from_calendar_date(2026, Month::June, 14).unwrap()),
            100,
        ),
        Err(ReferenceFarmWeatherReadinessError::InsufficientHistorical {
            required: MINIMUM_TRAINING_DAYS,
            actual: 100,
        })
    );
}
