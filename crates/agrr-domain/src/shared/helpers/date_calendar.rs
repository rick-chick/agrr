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
mod helpers_date_calendar_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/shared/helpers_date_calendar_test.rs"));
}
