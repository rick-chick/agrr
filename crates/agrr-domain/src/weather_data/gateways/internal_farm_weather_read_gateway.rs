use crate::weather_data::dtos::{
    InternalFarmWeatherDataListResult, InternalFarmWeatherStatusResult,
};

/// Ruby: `Domain::WeatherData::Gateways::InternalFarmWeatherReadGateway`
pub trait InternalFarmWeatherReadGateway: Send + Sync {
    fn weather_data_list_snapshot(
        &self,
        farm_id: &str,
    ) -> InternalFarmWeatherDataListResult;

    fn weather_status_snapshot(
        &self,
        farm_id: &str,
    ) -> InternalFarmWeatherStatusResult;
}
