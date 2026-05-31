//! GCS weather bulk JSON (`weather_data/{location_id}/{year}.json`).
//!
//! Ruby: `Adapters::WeatherData::Gateways::WeatherDataGcsHttpGateway`

mod gcs_object_client;
mod weather_data_gcs_gateway;
mod weather_json;

pub use weather_data_gcs_gateway::WeatherDataGcsBulkGateway;
pub use weather_json::{WeatherDataGcsConfig, WeatherDataGcsError, WeatherDataGcsReader, WeatherYearFile};
