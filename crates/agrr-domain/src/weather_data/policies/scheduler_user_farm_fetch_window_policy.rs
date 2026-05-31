//! Ruby: `UpdateUserFarmsWeatherDataJob` per-farm date range.

use time::Date;

use crate::shared::ports::ClockPort;
use crate::weather_data::helpers::subtract_days;

/// Fallback lookback when no weather data exists (Ruby `DEFAULT_LOOKBACK_DAYS`).
pub const SCHEDULER_USER_WEATHER_DEFAULT_LOOKBACK_DAYS: i64 = 7;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SchedulerUserFetchRange {
    pub start_date: Date,
    pub end_date: Date,
}

/// Ruby: `UpdateUserFarmsWeatherDataJob` per-farm window.
pub struct SchedulerUserFarmFetchWindowPolicy;

impl SchedulerUserFarmFetchWindowPolicy {
    /// `None` = skip this farm (already up to date or invalid range).
    pub fn fetch_range(
        latest_weather_date: Option<Date>,
        clock: &dyn ClockPort,
    ) -> Option<SchedulerUserFetchRange> {
        let today = clock.today();
        let start_date = match latest_weather_date {
            Some(latest) => latest + time::Duration::days(1),
            None => subtract_days(today, SCHEDULER_USER_WEATHER_DEFAULT_LOOKBACK_DAYS),
        };

        if start_date > today {
            return None;
        }

        let end_date = today;
        if start_date > end_date {
            return None;
        }

        Some(SchedulerUserFetchRange {
            start_date,
            end_date,
        })
    }
}

#[cfg(test)]
mod policies_scheduler_user_farm_fetch_window_policy_test_inline {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/weather_data/policies_scheduler_user_farm_fetch_window_policy_test.rs"
    ));
}
