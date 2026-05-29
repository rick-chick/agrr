//! Ruby: `Domain::WeatherData::Policies::WeatherPredictionHorizonPolicy`

use time::{Date, Month};

use crate::shared::ports::ClockPort;

/// Ruby: `Domain::WeatherData::Policies::WeatherPredictionHorizonPolicy`
pub struct WeatherPredictionHorizonPolicy;

impl WeatherPredictionHorizonPolicy {
    pub fn predict_days_to_next_year_end(end_date: Date, clock: &dyn ClockPort) -> i64 {
        let today = clock.today();
        let next_year_end =
            Date::from_calendar_date(today.year() + 1, Month::December, 31).unwrap_or(end_date);
        (next_year_end - end_date).whole_days()
    }
}

#[cfg(test)]
mod policies_weather_prediction_horizon_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/policies_weather_prediction_horizon_policy_test.rs"));
}
