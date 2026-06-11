//! Ruby: `Domain::WeatherData::Dtos::FarmWeatherDataAccessInput`

use time::Date;

/// Ruby: `Domain::WeatherData::Dtos::FarmWeatherDataAccessInput`
#[derive(Debug, Clone)]
pub struct FarmWeatherDataAccessInput {
    pub farm_id: i64,
    pub user_id: i64,
    pub is_admin: bool,
    pub predict: bool,
    pub start_date: Option<Date>,
    pub end_date: Option<Date>,
}

/// Ruby: `Domain::Farm::Dtos::FarmWeatherDataAccessContext`
#[derive(Debug, Clone)]
pub struct FarmWeatherDataAccessContext {
    pub farm_id: i64,
    pub display_name: String,
    pub latitude: f64,
    pub longitude: f64,
    pub weather_location_id: Option<i64>,
}
