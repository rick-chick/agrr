use time::Date;

use crate::weather_data::dtos::WeatherData;
use crate::weather_data::gateways::WeatherDataStorageError;

/// Narrow read port for observed weather rows in a date range.
pub trait FarmTemperatureChartWeatherGateway: Send + Sync {
    fn weather_data_for_period(
        &self,
        weather_location_id: i64,
        start_date: Date,
        end_date: Date,
    ) -> Result<Vec<WeatherData>, WeatherDataStorageError>;
}
