//! Ruby: agrr weather CLI gateway used by fetch perform interactor.

use serde_json::Value;
use time::Date;

/// Ruby: agrr weather fetch gateway
pub trait AgrrWeatherGateway: Send + Sync {
    fn fetch_by_date_range(
        &self,
        latitude: f64,
        longitude: f64,
        start_date: Date,
        end_date: Date,
        data_source: &str,
    ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>>;
}
