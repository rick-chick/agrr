//! Farm gateway methods used by weather_data interactors.

use serde_json::Value;

use crate::shared::exceptions::RecordNotFoundError;
use crate::weather_data::dtos::FarmWeatherDataAccessContext;

/// Minimal farm entity for data-source determination.
#[derive(Debug, Clone)]
pub struct FetchWeatherFarmEntity {
    pub region: Option<String>,
}

/// Ruby: farm gateway slice for weather data access + fetch perform.
pub trait WeatherDataFarmGateway: Send + Sync {
    fn farm_weather_data_access_context_for_owned_farm(
        &self,
        user_id: i64,
        farm_id: i64,
    ) -> Option<FarmWeatherDataAccessContext>;

    fn farm_weather_data_access_context_for_admin_lookup(
        &self,
        farm_id: i64,
    ) -> Option<FarmWeatherDataAccessContext>;

    fn update_predicted_weather_data(
        &self,
        farm_id: i64,
        payload: Option<Value>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;

    fn find_by_id(
        &self,
        farm_id: i64,
    ) -> Result<FetchWeatherFarmEntity, RecordNotFoundError>;

    fn update_weather_location_id(
        &self,
        farm_id: i64,
        weather_location_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>>;
}
