//! Observed weather rows for farm temperature chart via `WeatherDataGateway`.

use agrr_domain::farm::gateways::FarmTemperatureChartWeatherGateway;
use agrr_domain::weather_data::dtos::WeatherData;
use agrr_domain::weather_data::gateways::{WeatherDataGateway, WeatherDataStorageError};
use time::Date;

pub struct FarmTemperatureChartWeatherFromStorageGateway<'a> {
    weather_data: &'a dyn WeatherDataGateway,
}

impl<'a> FarmTemperatureChartWeatherFromStorageGateway<'a> {
    pub fn new(weather_data: &'a dyn WeatherDataGateway) -> Self {
        Self { weather_data }
    }
}

impl FarmTemperatureChartWeatherGateway for FarmTemperatureChartWeatherFromStorageGateway<'_> {
    fn weather_data_for_period(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<Vec<WeatherData>, WeatherDataStorageError> {
        self.weather_data
            .weather_data_for_period(weather_location_id, start_date, end_date)
    }
}
