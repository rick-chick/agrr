//! Ruby: `Domain::WeatherData::Policies::WeatherDataFetchWindowPolicy`

use time::Date;

use crate::shared::ports::ClockPort;
use crate::weather_data::helpers::{subtract_days, subtract_months};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct WeatherFetchRange {
    pub start_date: Date,
    pub end_date: Date,
    pub range_adjusted: bool,
}

/// Ruby: `Domain::WeatherData::Policies::WeatherDataFetchWindowPolicy`
pub struct WeatherDataFetchWindowPolicy;

impl WeatherDataFetchWindowPolicy {
    pub fn fetch_range(latest_weather_date: Option<Date>, clock: &dyn ClockPort) -> WeatherFetchRange {
        let today = clock.today();
        let start_date = subtract_months(today, 12 * 20);
        let minimum_end = subtract_days(today, 2);
        let end_date = latest_weather_date
            .map(|latest| latest.max(minimum_end))
            .unwrap_or(minimum_end);

        let (start_date, end_date, range_adjusted) = if start_date > end_date {
            (start_date, start_date + time::Duration::days(1), true)
        } else {
            (start_date, end_date, false)
        };

        WeatherFetchRange {
            start_date,
            end_date,
            range_adjusted,
        }
    }
}

#[cfg(test)]
mod policies_weather_data_fetch_window_policy_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/policies_weather_data_fetch_window_policy_test.rs"));
}
