//! Ruby: `Domain::WeatherData::Ports::WeatherPredictionAnchorsPort`

use time::Date;

use crate::weather_data::dtos::WeatherPredictionAnchors;

/// Ruby: `Domain::WeatherData::Ports::WeatherPredictionAnchorsPort`
pub trait WeatherPredictionAnchorsPort: Send + Sync {
    fn anchors_for(&self, reference_calendar_day: Date) -> WeatherPredictionAnchors;
}
