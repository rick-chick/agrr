// Tests for `policies/weather_data_fetch_window_policy.rs` (Ruby parity under test/domain/weather_data/).

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
