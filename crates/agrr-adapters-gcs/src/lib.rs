//! GCS weather bulk JSON (`weather_data/{location_id}/{year}.json`).
//!
//! Ruby: `Adapters::WeatherData::Gateways::WeatherDataGcsHttpGateway`

mod weather_json;

pub use weather_json::{WeatherDataGcsConfig, WeatherDataGcsReader, WeatherYearFile};
