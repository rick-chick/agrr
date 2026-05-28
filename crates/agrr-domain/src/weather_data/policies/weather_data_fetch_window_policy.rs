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
mod tests {
    use super::*;
    use time::{Date, Month, OffsetDateTime, Time};

    struct FakeClock {
        today: Date,
    }

    impl ClockPort for FakeClock {
        fn today(&self) -> Date {
            self.today
        }

        fn now(&self) -> OffsetDateTime {
            OffsetDateTime::new_utc(self.today, Time::MIDNIGHT)
        }
    }

    #[test]
    fn fetch_range_uses_latest_weather_date_and_minimum_today_minus_2() {
        let clock = FakeClock {
            today: Date::from_calendar_date(2026, Month::June, 15).expect("valid"),
        };
        let latest = Date::from_calendar_date(2025, Month::January, 1).expect("valid");
        let r = WeatherDataFetchWindowPolicy::fetch_range(Some(latest), &clock);
        assert_eq!(
            r.start_date,
            Date::from_calendar_date(2006, Month::June, 15).expect("valid")
        );
        assert_eq!(
            r.end_date,
            Date::from_calendar_date(2026, Month::June, 13).expect("valid")
        );
        assert!(!r.range_adjusted);
    }

    #[test]
    fn fetch_range_never_returns_start_date_after_end_date() {
        let clock = FakeClock {
            today: Date::from_calendar_date(2026, Month::August, 20).expect("valid"),
        };
        let r = WeatherDataFetchWindowPolicy::fetch_range(
            Some(Date::from_calendar_date(1900, Month::January, 1).expect("valid")),
            &clock,
        );
        assert!(r.start_date <= r.end_date);
        assert!(!r.range_adjusted);
    }
}
