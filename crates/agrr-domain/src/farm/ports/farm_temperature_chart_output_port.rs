use crate::farm::dtos::FarmTemperatureChartOutput;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FarmTemperatureChartFailure {
    NotFound,
    WeatherNotReady {
        status: String,
        progress: i32,
    },
    NoWeatherLocation,
    StorageUnavailable,
}

pub trait FarmTemperatureChartOutputPort {
    fn on_success(&mut self, output: FarmTemperatureChartOutput);
    fn on_failure(&mut self, failure: FarmTemperatureChartFailure);
}
