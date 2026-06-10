//! Incremental weather fetch: `latest + 1` through today (scheduler + reference optimization chain).

use time::Date;

use crate::shared::ports::ClockPort;
use crate::weather_data::helpers::subtract_days;
use super::WeatherFetchRange;

/// Fallback lookback when no weather data exists (Ruby `DEFAULT_LOOKBACK_DAYS`).
const DEFAULT_LOOKBACK_DAYS: i64 = 7;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) struct GapFillFetchRange {
    pub(crate) start_date: Date,
    pub(crate) end_date: Date,
}

/// Gap-fill window for scheduler jobs and reference-farm optimization chain fetch.
pub(crate) struct GapFillWeatherFetchWindowPolicy;

impl GapFillWeatherFetchWindowPolicy {
    /// `None` = skip this farm (already up to date or invalid range).
    pub(crate) fn fetch_range(
        latest_weather_date: Option<Date>,
        clock: &dyn ClockPort,
    ) -> Option<GapFillFetchRange> {
        let today = clock.today();
        let start_date = match latest_weather_date {
            Some(latest) => latest + time::Duration::days(1),
            None => subtract_days(today, DEFAULT_LOOKBACK_DAYS),
        };

        if start_date > today {
            return None;
        }

        let end_date = today;
        if start_date > end_date {
            return None;
        }

        Some(GapFillFetchRange {
            start_date,
            end_date,
        })
    }

    /// Optimization chain needs a concrete range; up-to-date farms use a no-op window.
    pub(crate) fn optimization_chain_fetch_range(
        latest_weather_date: Option<Date>,
        clock: &dyn ClockPort,
    ) -> WeatherFetchRange {
        match Self::fetch_range(latest_weather_date, clock) {
            Some(range) => WeatherFetchRange {
                start_date: range.start_date,
                end_date: range.end_date,
                range_adjusted: false,
            },
            None => {
                let today = clock.today();
                WeatherFetchRange {
                    start_date: today + time::Duration::days(1),
                    end_date: today,
                    range_adjusted: false,
                }
            }
        }
    }
}

#[cfg(test)]
mod policies_gap_fill_weather_fetch_window_policy_test_inline {
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/weather_data/policies_gap_fill_weather_fetch_window_policy_test.rs"
    ));
}
