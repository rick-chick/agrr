//! Ruby: `Domain::WeatherData::Interactors::InternalFarmWeatherStatusInteractor`

use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::weather_data::dtos::{
    InternalFarmWeatherFetchFailure, InternalFarmWeatherHttpStatus,
    InternalFarmWeatherReadInput, InternalFarmWeatherStatusResult,
};
use crate::weather_data::gateways::InternalFarmWeatherReadGateway;
use crate::weather_data::ports::InternalFarmWeatherStatusOutputPort;

pub struct InternalFarmWeatherStatusInteractor<'a, G, O, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    translator: &'a T,
}

impl<'a, G, O, T> InternalFarmWeatherStatusInteractor<'a, G, O, T>
where
    G: InternalFarmWeatherReadGateway,
    O: InternalFarmWeatherStatusOutputPort,
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
        match self.gateway.weather_status_snapshot(&farm_id) {
            InternalFarmWeatherStatusResult::FarmNotFound => {
                let opts = TranslateOptions::default();
                let message = self
                    .translator
                    .t("api.errors.common.farm_not_found", &opts);
                self.output_port.on_failure(InternalFarmWeatherFetchFailure {
                    message,
                    http_status: InternalFarmWeatherHttpStatus::NotFound,
                });
            }
            InternalFarmWeatherStatusResult::Ok(success) => {
                self.output_port.on_success(success);
            }
        }
    }
}

#[cfg(test)]
mod interactors_internal_farm_weather_status_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/interactors_internal_farm_weather_status_interactor_test.rs"));
}
