//! Ruby: `UpdateReferenceWeatherDataJob` date range (`WEATHER_DATA_LOOKBACK_DAYS`).

use time::Date;

use crate::shared::ports::ClockPort;
use crate::weather_data::helpers::subtract_days;

/// Past days to fetch for reference farms (Ruby `WEATHER_DATA_LOOKBACK_DAYS`).
pub const SCHEDULER_REFERENCE_WEATHER_LOOKBACK_DAYS: i64 = 7;

/// Ruby: `UpdateReferenceWeatherDataJob` fixed window — not `WeatherDataFetchWindowPolicy`.
pub struct SchedulerReferenceFarmFetchWindowPolicy;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct SchedulerReferenceFetchRange {
    pub start_date: Date,
    pub end_date: Date,
}

impl SchedulerReferenceFarmFetchWindowPolicy {
    /// Returns `None` when `start_date > end_date` (invalid range — job skips all fetches).
    pub fn fetch_range(clock: &dyn ClockPort) -> Option<SchedulerReferenceFetchRange> {
        let today = clock.today();
        let start_date = subtract_days(today, SCHEDULER_REFERENCE_WEATHER_LOOKBACK_DAYS);
        let end_date = today;
        if start_date > end_date {
            return None;
        }
        Some(SchedulerReferenceFetchRange {
            start_date,
            end_date,
        })
    }
}

#[cfg(test)]
mod policies_scheduler_reference_farm_fetch_window_policy_test_inline {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/weather_data/policies_scheduler_reference_farm_fetch_window_policy_test.rs"
    ));
}
