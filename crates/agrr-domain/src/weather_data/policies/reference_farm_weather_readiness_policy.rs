//! Reference-farm optimization chain bootstrap readiness (historical backfill gate).

use std::fmt;

use time::Date;

/// Matches `WeatherPredictionInteractor` training minimum (~18 years).
pub(crate) const MINIMUM_TRAINING_DAYS: i64 = 18 * 365;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ReferenceFarmWeatherReadinessError {
    NotBackfilled,
    InsufficientHistorical { required: i64, actual: i64 },
}

impl fmt::Display for ReferenceFarmWeatherReadinessError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::NotBackfilled => write!(f, "reference farm weather not backfilled"),
            Self::InsufficientHistorical { required, actual } => write!(
                f,
                "reference farm historical weather insufficient (required {required}, actual {actual})"
            ),
        }
    }
}

pub(crate) struct ReferenceFarmWeatherReadinessPolicy;

impl ReferenceFarmWeatherReadinessPolicy {
    pub(crate) fn validate(
        weather_location_id: Option<i64>,
        latest_weather_date: Option<Date>,
        historical_count: i64,
    ) -> Result<(), ReferenceFarmWeatherReadinessError> {
        if weather_location_id.is_none() || latest_weather_date.is_none() {
            return Err(ReferenceFarmWeatherReadinessError::NotBackfilled);
        }
        if historical_count < MINIMUM_TRAINING_DAYS {
            return Err(ReferenceFarmWeatherReadinessError::InsufficientHistorical {
                required: MINIMUM_TRAINING_DAYS,
                actual: historical_count,
            });
        }
        Ok(())
    }
}

#[cfg(test)]
mod policies_reference_farm_weather_readiness_policy_test_inline {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/weather_data/policies_reference_farm_weather_readiness_policy_test.rs"
    ));
}
