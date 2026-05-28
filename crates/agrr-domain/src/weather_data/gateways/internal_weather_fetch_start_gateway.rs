//! Ruby: `Domain::WeatherData::Gateways::InternalWeatherFetchStartGateway`

use crate::weather_data::dtos::InternalWeatherFetchStartOutput;

/// Ruby snapshot struct
#[derive(Debug, Clone)]
pub struct WeatherFetchFarmSnapshot {
    pub farm_id: i64,
    pub weather_data_status: String,
    pub weather_data_count: Option<i32>,
    pub total_blocks: i32,
}

#[derive(Debug, Clone)]
pub enum StartInternalWeatherFetchResult {
    FarmNotFound,
    Completed(WeatherFetchFarmSnapshot),
    Started(WeatherFetchFarmSnapshot),
    NeedsFetch(WeatherFetchFarmSnapshot),
    Failed(String),
}

/// Ruby: `Domain::WeatherData::Gateways::InternalWeatherFetchStartGateway`
pub trait InternalWeatherFetchStartGateway: Send + Sync {
    fn start_internal_weather_data_fetch(
        &self,
        farm_id: &str,
    ) -> StartInternalWeatherFetchResult;
}

/// Started farm snapshot after triggering fetch (farm interactor result).
#[derive(Debug, Clone)]
pub struct StartedFarmWeatherFetchSnapshot {
    pub weather_data_status: String,
    pub weather_data_total_years: i32,
}

/// Ruby: farm gateway slice for weather fetch start.
pub trait StartFarmWeatherDataFetchPort: Send + Sync {
    fn call(
        &self,
        farm_id: i64,
        as_of: time::Date,
    ) -> Option<StartedFarmWeatherFetchSnapshot>;
}
