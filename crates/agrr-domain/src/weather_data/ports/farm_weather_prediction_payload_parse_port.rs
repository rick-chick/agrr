//! Ruby: `Domain::WeatherData::Ports::FarmWeatherPredictionPayloadParsePort`

use time::{Date, OffsetDateTime};

/// Ruby: payload parse port for cached prediction metadata.
pub trait FarmWeatherPredictionPayloadParsePort: Send + Sync {
    fn predicted_at_from_payload(&self, value: Option<&str>) -> Option<OffsetDateTime>;

    fn prediction_start_date_from_payload(&self, value: Option<&str>) -> Option<Date>;
}
