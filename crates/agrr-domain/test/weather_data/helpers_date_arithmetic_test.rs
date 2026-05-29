// Tests for `helpers/date_arithmetic.rs` (Ruby parity under test/domain/weather_data/).

    use time::Month;

    #[test]
    fn subtract_months_matches_ruby_shift() {
        let d = Date::from_calendar_date(2026, Month::June, 15).expect("valid");
        let r = subtract_months(d, 12 * 20);
        assert_eq!(r, Date::from_calendar_date(2006, Month::June, 15).expect("valid"));
    }
