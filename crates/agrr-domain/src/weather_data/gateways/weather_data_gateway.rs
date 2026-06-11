//! Ruby: `Domain::WeatherData::Gateways::WeatherDataGateway`

use time::Date;

use crate::weather_data::dtos::WeatherData;
use crate::weather_data::gateways::WeatherDataStorageError;

/// Minimal weather location record returned by gateway lookups.
#[derive(Debug, Clone)]
pub struct WeatherLocationRecord {
    pub id: i64,
}

/// Ruby: `Domain::WeatherData::Gateways::WeatherDataGateway`
pub trait WeatherDataGateway: Send + Sync {
    fn weather_data_for_period(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<Vec<WeatherData>, WeatherDataStorageError>;

    fn weather_data_count(
        &self,
        weather_location_id: i64,
        start_date: Option<Date>,
        end_date: Option<Date>,
    ) -> Result<i64, WeatherDataStorageError>;

    fn historical_data_count(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<i64, WeatherDataStorageError>;

    fn earliest_date(
        &self,
        weather_location_id: i64,
    ) -> Result<Option<Date>, WeatherDataStorageError>;

    fn latest_date(
        &self,
        weather_location_id: i64,
    ) -> Result<Option<Date>, WeatherDataStorageError>;

    fn upsert_weather_data(
        &self,
        weather_data_dtos: &[WeatherData],
        weather_location_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn find_by_coordinates(
        &self,
        latitude: f64,
        longitude: f64,
    ) -> Option<WeatherLocationRecord>;

    fn find_or_create_weather_location(
        &self,
        latitude: f64,
        longitude: f64,
        elevation: Option<f64>,
        timezone: Option<&str>,
    ) -> Result<WeatherLocationRecord, Box<dyn std::error::Error + Send + Sync>>;
}
