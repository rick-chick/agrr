//! Ruby: `Domain::WeatherData::OptimizationJobChainWeatherComputation`

use crate::shared::ports::ClockPort;
use crate::weather_data::policies::{
    WeatherDataFetchWindowPolicy, WeatherFetchRange, WeatherPredictionHorizonPolicy,
};
use time::Date;

/// Ruby: `Domain::WeatherData::OptimizationJobChainWeatherComputation`
pub struct OptimizationJobChainWeatherComputation;

impl OptimizationJobChainWeatherComputation {
    pub fn weather_window(
        latest_weather_date: Option<Date>,
        clock: &dyn ClockPort,
    ) -> WeatherFetchRange {
        WeatherDataFetchWindowPolicy::fetch_range(latest_weather_date, clock)
    }

    pub fn predict_days_to_next_year_end(end_date: Date, clock: &dyn ClockPort) -> i64 {
        WeatherPredictionHorizonPolicy::predict_days_to_next_year_end(end_date, clock)
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

    // Ruby: test "weather_window delegates to WeatherDataFetchWindowPolicy"
    #[test]
    fn weather_window_delegates_to_weather_data_fetch_window_policy() {
        let clock = FakeClock {
            today: Date::from_calendar_date(2026, Month::June, 15).unwrap(),
        };
        let latest = Date::from_calendar_date(2025, Month::January, 1).unwrap();
        let expected =
            WeatherDataFetchWindowPolicy::fetch_range(Some(latest), &clock);

        assert_eq!(
            OptimizationJobChainWeatherComputation::weather_window(Some(latest), &clock),
            expected
        );
    }

    // Ruby: test "predict_days_to_next_year_end delegates to WeatherPredictionHorizonPolicy"
    #[test]
    fn predict_days_to_next_year_end_delegates_to_weather_prediction_horizon_policy() {
        let clock = FakeClock {
            today: Date::from_calendar_date(2026, Month::May, 6).unwrap(),
        };
        let end_date = Date::from_calendar_date(2026, Month::May, 1).unwrap();
        let expected =
            WeatherPredictionHorizonPolicy::predict_days_to_next_year_end(end_date, &clock);

        assert_eq!(
            OptimizationJobChainWeatherComputation::predict_days_to_next_year_end(end_date, &clock),
            expected
        );
    }
}
