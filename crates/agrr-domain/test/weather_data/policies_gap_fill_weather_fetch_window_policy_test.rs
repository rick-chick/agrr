// Tests for `policies/gap_fill_weather_fetch_window_policy.rs`.

use crate::shared::ports::ClockPort;
use crate::weather_data::policies::GapFillWeatherFetchWindowPolicy;
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
fn fetch_range_uses_latest_plus_one_through_day_before_yesterday() {
    let clock = FakeClock {
        today: Date::from_calendar_date(2026, Month::June, 15).expect("valid"),
    };
    let latest = Date::from_calendar_date(2026, Month::June, 10).expect("valid");
    let range = GapFillWeatherFetchWindowPolicy::fetch_range(Some(latest), &clock).expect("range");
    assert_eq!(
        range.start_date,
        Date::from_calendar_date(2026, Month::June, 11).expect("valid")
    );
    assert_eq!(
        range.end_date,
        Date::from_calendar_date(2026, Month::June, 13).expect("valid")
    );
}

#[test]
fn fetch_range_without_latest_uses_seven_day_lookback() {
    let clock = FakeClock {
        today: Date::from_calendar_date(2026, Month::June, 15).expect("valid"),
    };
    let range = GapFillWeatherFetchWindowPolicy::fetch_range(None, &clock).expect("range");
    assert_eq!(
        range.start_date,
        Date::from_calendar_date(2026, Month::June, 8).expect("valid")
    );
    assert_eq!(
        range.end_date,
        Date::from_calendar_date(2026, Month::June, 13).expect("valid")
    );
}

#[test]
fn fetch_range_skips_when_already_up_to_date() {
    let clock = FakeClock {
        today: Date::from_calendar_date(2026, Month::June, 15).expect("valid"),
    };
    let day_before_yesterday =
        Date::from_calendar_date(2026, Month::June, 13).expect("valid");
    assert!(GapFillWeatherFetchWindowPolicy::fetch_range(
        Some(day_before_yesterday),
        &clock
    )
    .is_none());
}

#[test]
fn optimization_chain_fetch_range_uses_no_op_when_up_to_date() {
    let clock = FakeClock {
        today: Date::from_calendar_date(2026, Month::June, 15).expect("valid"),
    };
    let day_before_yesterday =
        Date::from_calendar_date(2026, Month::June, 13).expect("valid");
    let range = GapFillWeatherFetchWindowPolicy::optimization_chain_fetch_range(
        Some(day_before_yesterday),
        &clock,
    );
    assert!(range.start_date > range.end_date);
}
