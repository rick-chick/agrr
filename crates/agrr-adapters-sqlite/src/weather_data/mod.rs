mod internal_farm_weather_read_gateway;
mod internal_weather_fetch_start_gateway;
mod weather_bulk_metadata;
mod weather_bulk_metadata_gcs_sync;
mod weather_bulk_metadata_store;
mod predicted_weather_gateway_bundle;
mod predicted_weather_metadata_gateway;
mod weather_data_farm_gateway;
mod weather_data_gateway;
mod weather_data_gateway_bundle;

#[cfg(test)]
mod weather_data_gateway_test;

#[cfg(test)]
pub(crate) mod gcs_weather_test_support;

pub use internal_farm_weather_read_gateway::InternalFarmWeatherReadSqliteGateway;
pub use internal_weather_fetch_start_gateway::InternalWeatherFetchStartSqliteGateway;
pub use weather_data_farm_gateway::WeatherDataFarmSqliteGateway;
pub use weather_data_gateway::WeatherDataSqliteGateway;
pub use predicted_weather_gateway_bundle::PredictedWeatherGatewayBundle;
pub use predicted_weather_metadata_gateway::PredictedWeatherMetadataSqliteGateway;
pub use weather_data_gateway_bundle::{
    validate_weather_storage_config, WeatherDataGatewayBundle,
};
