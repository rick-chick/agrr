// Tests for `policies/scheduler_reference_farm_fetch_window_policy.rs` (Ruby parity: test/domain/weather_data/policies/scheduler_reference_farm_fetch_window_policy_test.rb).

use crate::shared::ports::ClockPort;
use crate::weather_data::policies::{
    SchedulerReferenceFarmFetchWindowPolicy, SCHEDULER_REFERENCE_WEATHER_LOOKBACK_DAYS,
};
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
fn reference_fetch_range_is_today_minus_7_through_today() {
    let clock = FakeClock {
        today: Date::from_calendar_date(2026, Month::May, 1).expect("valid"),
    };
    let range = SchedulerReferenceFarmFetchWindowPolicy::fetch_range(&clock)
        .expect("valid range");
    assert_eq!(
        range.start_date,
        Date::from_calendar_date(2026, Month::April, 24).expect("valid")
    );
    assert_eq!(range.end_date, clock.today);
    assert_eq!(SCHEDULER_REFERENCE_WEATHER_LOOKBACK_DAYS, 7);
}
