//! Calendar date helpers mirroring Ruby `Date#<<` (month subtraction).

use time::{Date, Month};

/// Ruby: `date << months` — subtract `months` calendar months.
pub fn subtract_months(date: Date, months: u32) -> Date {
    let year = date.year();
    let month0 = date.month() as i32 - 1;
    let day = date.day();
    let total = year * 12 + month0 - months as i32;
    let new_year = total.div_euclid(12);
    let new_month0 = total.rem_euclid(12);
    let new_month = Month::try_from((new_month0 + 1) as u8).unwrap_or(Month::January);
    Date::from_calendar_date(new_year, new_month, day)
        .or_else(|_| {
            let last = last_day_of_month(new_year, new_month);
            Date::from_calendar_date(new_year, new_month, last)
        })
        .unwrap_or(date)
}

fn last_day_of_month(year: i32, month: Month) -> u8 {
    match month {
        Month::February => {
            if is_leap_year(year) {
                29
            } else {
                28
            }
        }
        Month::April | Month::June | Month::September | Month::November => 30,
        _ => 31,
    }
}

fn is_leap_year(year: i32) -> bool {
    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
}

/// Ruby: `date - days`
pub fn subtract_days(date: Date, days: i64) -> Date {
    date - time::Duration::days(days)
}

/// Parse `YYYY-MM-DD` (first 10 chars of ISO strings).
pub fn parse_iso_date(value: &str) -> Option<Date> {
    let trimmed = value.trim();
    if trimmed.len() < 10 {
        return None;
    }
    let date_part = &trimmed[..10];
    let parts: Vec<&str> = date_part.split('-').collect();
    if parts.len() != 3 {
        return None;
    }
    let year: i32 = parts[0].parse().ok()?;
    let month_num: u8 = parts[1].parse().ok()?;
    let day: u8 = parts[2].parse().ok()?;
    let month = Month::try_from(month_num).ok()?;
    Date::from_calendar_date(year, month, day).ok()
}

#[cfg(test)]
mod helpers_date_arithmetic_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/helpers_date_arithmetic_test.rs"));
}
