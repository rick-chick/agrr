//! GCS weather bulk JSON (`weather_data/{location_id}/{year}.json`).
//!
//! Ruby: `Adapters::WeatherData::Gateways::WeatherDataGcsHttpGateway`

mod gcs_io_counters;
mod gcs_object_client;
mod gcs_read_log;
mod predicted_weather_store_gateway;
mod weather_data_gcs_gateway;
mod weather_json;

pub use gcs_io_counters::GcsIoSnapshot;
pub use gcs_read_log::set_gcs_read_log_suffix;
#[doc(hidden)]
pub use gcs_read_log::gcs_read_log_suffix_snapshot;
pub use gcs_object_client::preload_blocking_http_client;
pub use predicted_weather_store_gateway::PredictedWeatherGcsStoreGateway;
pub use weather_data_gcs_gateway::WeatherDataGcsBulkGateway;
pub use weather_json::{WeatherDataGcsConfig, WeatherDataGcsError, WeatherDataGcsReader, WeatherYearFile};
