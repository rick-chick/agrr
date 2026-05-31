use serde_json::Value;
use time::Date;

use crate::field_cultivation::dtos::ClimateObservedWeatherDatum;
use crate::weather_data::gateways::WeatherDataStorageError;

pub trait FieldCultivationWeatherDataGateway: Send + Sync {
    fn weather_data_for_period(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<Vec<ClimateObservedWeatherDatum>, WeatherDataStorageError>;

    fn format_for_agrr(
        &self,
        weather_data_dtos: &[ClimateObservedWeatherDatum],
        weather_location: &Value,
    ) -> Value;
}
