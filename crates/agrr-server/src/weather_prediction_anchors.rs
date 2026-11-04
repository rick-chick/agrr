//! Ruby: `Adapters::WeatherData::Ports::RailsWeatherPredictionAnchorsAdapter`

use agrr_domain::weather_data::dtos::WeatherPredictionAnchors;
use agrr_domain::weather_data::ports::WeatherPredictionAnchorsPort;
use time::{Date, Month};

pub struct SystemWeatherPredictionAnchors;

impl WeatherPredictionAnchorsPort for SystemWeatherPredictionAnchors {
    fn anchors_for(&self, reference_calendar_day: Date) -> WeatherPredictionAnchors {
        let training_end = reference_calendar_day.saturating_sub(time::Duration::days(2));
        let training_start = Date::from_calendar_date(
            reference_calendar_day.year().saturating_sub(20),
            Month::January,
            1,
        )
        .unwrap_or(training_end);
        let current_year_history_start =
            Date::from_calendar_date(reference_calendar_day.year(), Month::January, 1)
                .unwrap_or(training_end);
        let default_target_end = add_months(reference_calendar_day, 6);
        WeatherPredictionAnchors {
            training_start_date: training_start,
            training_end_date: training_end,
            current_year_history_start_date: current_year_history_start,
            current_year_history_end_date: training_end,
            default_target_end_date: default_target_end,
        }
    }
}

fn add_months(date: Date, months: u8) -> Date {
    let mut month = date.month() as u8 + months;
    let mut year = date.year();
    while month > 12 {
        month -= 12;
        year += 1;
    }
    let day = date.day().min(days_in_month(year, month));
    Date::from_calendar_date(year, Month::try_from(month).unwrap_or(Month::December), day)
        .unwrap_or(date)
}

fn days_in_month(year: i32, month: u8) -> u8 {
    match month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 => {
            if (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 {
                29
            } else {
                28
            }
        }
        _ => 30,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::weather_data::ports::WeatherPredictionAnchorsPort;
    use time::{Date, Month};

    fn date(y: i32, m: u8, d: u8) -> Date {
        Date::from_calendar_date(y, Month::try_from(m).unwrap(), d).unwrap()
    }

    #[test]
    fn anchors_for_uses_reference_minus_two_days_as_training_end() {
        let reference = date(2026, 6, 15);
        let anchors = SystemWeatherPredictionAnchors.anchors_for(reference);
        assert_eq!(anchors.training_end_date, date(2026, 6, 13));
        assert_eq!(anchors.current_year_history_end_date, date(2026, 6, 13));
    }

    #[test]
    fn anchors_for_starts_training_twenty_years_before_reference_year() {
        let reference = date(2026, 6, 15);
        let anchors = SystemWeatherPredictionAnchors.anchors_for(reference);
        assert_eq!(anchors.training_start_date, date(2006, 1, 1));
        assert_eq!(anchors.current_year_history_start_date, date(2026, 1, 1));
    }

    #[test]
    fn anchors_for_default_target_end_is_six_months_ahead() {
        let reference = date(2026, 1, 10);
        let anchors = SystemWeatherPredictionAnchors.anchors_for(reference);
        assert_eq!(anchors.default_target_end_date, date(2026, 7, 10));
    }

    #[test]
    fn add_months_clamps_day_when_target_month_is_shorter() {
        assert_eq!(add_months(date(2026, 1, 31), 1), date(2026, 2, 28));
        assert_eq!(add_months(date(2024, 1, 31), 1), date(2024, 2, 29));
    }

    #[test]
    fn days_in_month_handles_leap_february() {
        assert_eq!(days_in_month(2024, 2), 29);
        assert_eq!(days_in_month(2025, 2), 28);
    }
}
