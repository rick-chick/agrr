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

    #[test]
    fn weather_window_delegates_to_weather_data_fetch_window_policy_for_user_farms() {
        let clock = FakeClock {
            today: Date::from_calendar_date(2026, Month::June, 15).unwrap(),
        };
        let latest = Date::from_calendar_date(2025, Month::January, 1).unwrap();
        let expected =
            WeatherDataFetchWindowPolicy::fetch_range(Some(latest), &clock);

        assert_eq!(
            OptimizationJobChainWeatherComputation::weather_window(Some(latest), &clock, false),
            expected
        );
    }

    #[test]
    fn weather_window_delegates_to_gap_fill_policy_for_reference_farms() {
        let clock = FakeClock {
            today: Date::from_calendar_date(2026, Month::June, 15).unwrap(),
        };
        let latest = Date::from_calendar_date(2026, Month::June, 10).unwrap();
        let expected =
            GapFillWeatherFetchWindowPolicy::optimization_chain_fetch_range(Some(latest), &clock);

        assert_eq!(
            OptimizationJobChainWeatherComputation::weather_window(Some(latest), &clock, true),
            expected
        );
    }

    #[test]
    fn ensure_reference_farm_weather_ready_delegates_to_readiness_policy() {
        let err = OptimizationJobChainWeatherComputation::ensure_reference_farm_weather_ready(
            Some(1),
            None,
            10_000,
        )
        .expect_err("missing latest");
        assert!(err.contains("not backfilled"));
    }

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
