use time::Date;

/// Ruby: `Domain::WeatherData::Mappers::AdjustObservedWeatherWindowMapper`
pub fn historical_fetch_window(effective_planning_start: Date, today: Date) -> (Date, Date) {
    let current_year_start = Date::from_calendar_date(today.year(), time::Month::January, 1)
        .unwrap_or(today);
    let start_date = if effective_planning_start < current_year_start {
        effective_planning_start
    } else {
        current_year_start
    };
    let end_date = today
        .checked_sub(time::Duration::days(1))
        .unwrap_or(today);
    (start_date, end_date)
}

#[cfg(test)]
mod adjust_observed_weather_window_mapper_test_inline {
    use super::*;
    use time::macros::date;

    #[test]
    fn includes_current_year_start_when_planning_starts_mid_year() {
        let (start, end) = historical_fetch_window(date!(2026 - 03 - 01), date!(2026 - 05 - 31));
        assert_eq!(start, date!(2026 - 01 - 01));
        assert_eq!(end, date!(2026 - 05 - 30));
    }

    #[test]
    fn keeps_earlier_planning_start_across_year_boundary() {
        let (start, end) = historical_fetch_window(date!(2025 - 06 - 01), date!(2026 - 05 - 31));
        assert_eq!(start, date!(2025 - 06 - 01));
        assert_eq!(end, date!(2026 - 05 - 30));
    }
}
