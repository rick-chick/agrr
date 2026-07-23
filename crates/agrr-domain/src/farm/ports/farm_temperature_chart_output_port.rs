use crate::farm::dtos::FarmTemperatureChartOutput;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait FarmTemperatureChartOutputPort {
    fn on_success(&mut self, output: FarmTemperatureChartOutput);
    fn on_failure(&mut self, error: TemperatureChartFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum TemperatureChartFailure {
    Policy(PolicyPermissionDenied),
    NotFound(Error),
    WeatherNotReady {
        status: String,
        progress: i32,
    },
    MissingWeatherLocation(Error),
    Storage(Error),
}
