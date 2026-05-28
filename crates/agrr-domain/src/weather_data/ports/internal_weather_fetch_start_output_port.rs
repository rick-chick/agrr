//! Ruby: `Domain::WeatherData::Ports::InternalWeatherFetchStartOutputPort`

use crate::weather_data::dtos::{InternalWeatherFetchFailure, InternalWeatherFetchStartOutput};

/// Ruby: `Domain::WeatherData::Ports::InternalWeatherFetchStartOutputPort`
pub trait InternalWeatherFetchStartOutputPort {
    fn on_success(&mut self, dto: InternalWeatherFetchStartOutput);
    fn on_failure(&mut self, dto: InternalWeatherFetchFailure);
}
