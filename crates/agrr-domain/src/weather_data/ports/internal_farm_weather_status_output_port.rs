use crate::weather_data::dtos::{
    InternalFarmWeatherFetchFailure, InternalFarmWeatherStatusOutput,
};

pub trait InternalFarmWeatherStatusOutputPort {
    fn on_success(&mut self, dto: InternalFarmWeatherStatusOutput);
    fn on_failure(&mut self, dto: InternalFarmWeatherFetchFailure);
}
