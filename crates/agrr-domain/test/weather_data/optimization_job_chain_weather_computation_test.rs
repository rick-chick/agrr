// Tests for `optimization_job_chain_weather_computation.rs` (Ruby parity under test/domain/weather_data/).

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
