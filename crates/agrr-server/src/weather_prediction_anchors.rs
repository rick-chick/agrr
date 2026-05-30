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
