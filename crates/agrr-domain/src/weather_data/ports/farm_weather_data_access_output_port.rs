//! Ruby: `Domain::WeatherData::Ports::FarmWeatherDataAccessOutputPort`

use time::Date;

#[derive(Debug, Clone, PartialEq)]
pub struct FarmWeatherIndexRow {
    pub date: Date,
    pub temperature_max: f64,
    pub temperature_min: f64,
    pub temperature_mean: f64,
    pub precipitation: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct FarmWeatherFarmSummary {
    pub id: i64,
    pub name: String,
    pub latitude: f64,
    pub longitude: f64,
}

#[derive(Debug, Clone, PartialEq)]
pub struct FarmWeatherPeriod {
    pub start_date: Date,
    pub end_date: Date,
}

#[derive(Debug, Clone, PartialEq)]
pub struct FarmWeatherPredictionPeriod {
    pub start_date: String,
    pub end_date: String,
}

/// Ruby: `Domain::WeatherData::Ports::FarmWeatherDataAccessOutputPort`
pub trait FarmWeatherDataAccessOutputPort {
    fn on_index_success(
        &mut self,
        farm: FarmWeatherFarmSummary,
        period: FarmWeatherPeriod,
        data: Vec<FarmWeatherIndexRow>,
    );

    fn on_prediction_cached_success(
        &mut self,
        farm: FarmWeatherFarmSummary,
        period: FarmWeatherPredictionPeriod,
        is_prediction: bool,
        predicted_at: Option<String>,
        model: Option<String>,
        data: Vec<FarmWeatherIndexRow>,
    );

    fn on_prediction_queued(&mut self, farm_id: i64, farm_name: String);

    fn on_farm_not_found(&mut self);

    fn on_no_weather_location(&mut self);

    fn on_insufficient_historical_data(&mut self);

    fn on_weather_data_storage_unavailable(&mut self);

    fn on_enqueue_failed(&mut self, error_message: String);
}
