//! Ruby: `Domain::WeatherData::Interactors::InternalFarmWeatherDataListInteractor`

use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::weather_data::dtos::{
    InternalFarmWeatherDataListResult, InternalFarmWeatherFetchFailure,
    InternalFarmWeatherHttpStatus, InternalFarmWeatherReadInput,
};
use crate::weather_data::gateways::InternalFarmWeatherReadGateway;
use crate::weather_data::ports::InternalFarmWeatherDataListOutputPort;

pub struct InternalFarmWeatherDataListInteractor<'a, G, O, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    translator: &'a T,
}

impl<'a, G, O, T> InternalFarmWeatherDataListInteractor<'a, G, O, T>
where
    G: InternalFarmWeatherReadGateway,
    O: InternalFarmWeatherDataListOutputPort,
    T: TranslatorPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G, translator: &'a T) -> Self {
        Self {
            output_port,
            gateway,
            translator,
        }
    }

    pub fn call(&mut self, input: InternalFarmWeatherReadInput) {
        let farm_id = input.farm_id;
        match self.gateway.weather_data_list_snapshot(&farm_id) {
            InternalFarmWeatherDataListResult::FarmNotFound => {
                let opts = TranslateOptions::default();
                let message = self
                    .translator
                    .t("api.errors.common.farm_not_found", &opts);
                self.output_port.on_failure(InternalFarmWeatherFetchFailure {
                    message,
                    http_status: InternalFarmWeatherHttpStatus::NotFound,
                });
            }
            InternalFarmWeatherDataListResult::WeatherLocationNotFound => {
                let opts = TranslateOptions::default();
                let message = self
                    .translator
                    .t("api.errors.common.weather_location_not_found", &opts);
                self.output_port.on_failure(InternalFarmWeatherFetchFailure {
                    message,
                    http_status: InternalFarmWeatherHttpStatus::NotFound,
                });
            }
            InternalFarmWeatherDataListResult::Ok(success) => {
                self.output_port.on_success(success);
            }
        }
    }
}

#[cfg(test)]
mod interactors_internal_farm_weather_data_list_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/interactors_internal_farm_weather_data_list_interactor_test.rs"));
}
