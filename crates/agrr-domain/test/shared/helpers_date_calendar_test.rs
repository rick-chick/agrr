// Tests for `helpers/date_calendar.rs` (Ruby parity under test/domain/shared/).


    fn d(y: i32, m: u8, day: u8) -> Date {
        Date::from_calendar_date(y, Month::try_from(m).expect("month"), day).expect("valid date")
    }

    #[test]
    fn beginning_of_month_works() {
        let input = d(2024, 6, 15);
        assert_eq!(beginning_of_month(input), d(2024, 6, 1));
    }

    #[test]
    fn end_of_month_leap_and_non_leap() {
        assert_eq!(end_of_month(d(2024, 2, 1)), d(2024, 2, 29));
        assert_eq!(end_of_month(d(2023, 2, 15)), d(2023, 2, 28));
    }

    #[test]
    fn beginning_and_end_of_year() {
        let input = d(2024, 7, 1);
        assert_eq!(beginning_of_year(input), d(2024, 1, 1));
        assert_eq!(end_of_year(input), d(2024, 12, 31));
    }

    #[test]
    fn first_day_of_next_calendar_month_works() {
        assert_eq!(
            first_day_of_next_calendar_month(d(2024, 3, 5)),
            d(2024, 4, 1)
        );
        assert_eq!(
            first_day_of_next_calendar_month(d(2024, 3, 1)),
            d(2024, 4, 1)
        );
    }
