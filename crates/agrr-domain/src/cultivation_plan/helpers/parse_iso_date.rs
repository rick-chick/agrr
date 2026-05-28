use time::{Date, Month};

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
