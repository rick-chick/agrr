use crate::weather_data::dtos::{
    InternalFarmWeatherDataListOutput, InternalFarmWeatherFetchFailure,
};

pub trait InternalFarmWeatherDataListOutputPort {
    fn on_success(&mut self, dto: InternalFarmWeatherDataListOutput);
    fn on_failure(&mut self, dto: InternalFarmWeatherFetchFailure);
}
