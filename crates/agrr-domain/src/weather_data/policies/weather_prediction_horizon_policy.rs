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
mod tests {
    use super::*;
    use time::{Date, Month, OffsetDateTime, Time};

    struct FakeClock {
        today: Date,
    }

    impl crate::shared::ports::ClockPort for FakeClock {
        fn today(&self) -> Date {
            self.today
        }

        fn now(&self) -> OffsetDateTime {
            OffsetDateTime::new_utc(self.today, Time::MIDNIGHT)
        }
    }

    #[test]
    fn predict_days_to_next_year_end_counts_days_to_dec_31_next_calendar_year() {
        let clock = FakeClock {
            today: Date::from_calendar_date(2026, Month::May, 6).expect("valid"),
        };
        let end_date = Date::from_calendar_date(2026, Month::May, 1).expect("valid");
        let next_end = Date::from_calendar_date(2027, Month::December, 31).expect("valid");
        let days = WeatherPredictionHorizonPolicy::predict_days_to_next_year_end(end_date, &clock);
        assert_eq!(days, (next_end - end_date).whole_days());
    }
}
