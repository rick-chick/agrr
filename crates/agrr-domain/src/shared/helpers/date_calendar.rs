//! Ruby: `Domain::Shared::DateCalendar` — calendar helpers without ActiveSupport.

use time::{Date, Month};

/// Ruby: `DateCalendar.beginning_of_month`
pub fn beginning_of_month(date: Date) -> Date {
    Date::from_calendar_date(date.year(), date.month(), 1).expect("valid month start")
}

/// Ruby: `DateCalendar.end_of_month`
pub fn end_of_month(date: Date) -> Date {
    first_day_of_next_calendar_month(date) - time::Duration::days(1)
}

/// Ruby: `DateCalendar.beginning_of_year`
pub fn beginning_of_year(date: Date) -> Date {
    Date::from_calendar_date(date.year(), Month::January, 1).expect("valid year start")
}

/// Ruby: `DateCalendar.end_of_year`
pub fn end_of_year(date: Date) -> Date {
    Date::from_calendar_date(date.year(), Month::December, 31).expect("valid year end")
}

/// Ruby: `DateCalendar.first_day_of_next_calendar_month`
pub fn first_day_of_next_calendar_month(date: Date) -> Date {
    let y = date.year();
    let (next_y, next_m) = if date.month() == Month::December {
        (y + 1, Month::January)
    } else {
        let next_m = Month::try_from(u8::from(date.month()) + 1).expect("month");
        (y, next_m)
    };
    Date::from_calendar_date(next_y, next_m, 1).expect("valid next month start")
}

#[cfg(test)]
mod tests {
    use super::*;

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
}
