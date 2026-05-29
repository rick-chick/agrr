//! Ruby: `Domain::WeatherData::Interactors::InternalWeatherFetchStartInteractor`

use std::collections::BTreeMap;

use crate::shared::ports::TranslatorPort;
use crate::weather_data::dtos::{
    InternalWeatherFetchFailure, InternalWeatherFetchHttpStatus, InternalWeatherFetchStartInput,
    InternalWeatherFetchStartOutput, InternalWeatherFetchStartVariant,
};
use crate::weather_data::gateways::{
    InternalWeatherFetchStartGateway, StartFarmWeatherDataFetchPort,
    StartInternalWeatherFetchResult, WeatherFetchFarmSnapshot,
};
use crate::weather_data::ports::InternalWeatherFetchStartOutputPort;

/// Ruby: `Domain::WeatherData::Interactors::InternalWeatherFetchStartInteractor`
pub struct InternalWeatherFetchStartInteractor<'a, O, T> {
    output_port: &'a mut O,
    gateway: &'a dyn InternalWeatherFetchStartGateway,
    translator: &'a T,
    start_farm_weather_data_fetch: &'a dyn StartFarmWeatherDataFetchPort,
    calendar_today: time::Date,
}

impl<'a, O, T> InternalWeatherFetchStartInteractor<'a, O, T>
where
    O: InternalWeatherFetchStartOutputPort,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        gateway: &'a dyn InternalWeatherFetchStartGateway,
        translator: &'a T,
        start_farm_weather_data_fetch: &'a dyn StartFarmWeatherDataFetchPort,
        calendar_today: time::Date,
    ) -> Self {
        Self {
            output_port,
            gateway,
            translator,
            start_farm_weather_data_fetch,
            calendar_today,
        }
    }

    pub fn call(&mut self, input: InternalWeatherFetchStartInput) {
        match self
            .gateway
            .start_internal_weather_data_fetch(&input.farm_id)
        {
            StartInternalWeatherFetchResult::FarmNotFound => {
                let message = self
                    .translator
                    .t("api.errors.common.farm_not_found", &BTreeMap::new());
                self.output_port.on_failure(InternalWeatherFetchFailure {
                    message,
                    http_status: InternalWeatherFetchHttpStatus::NotFound,
                });
            }
            StartInternalWeatherFetchResult::Completed(snap) => {
                self.output_port
                    .on_success(map_success(snap, InternalWeatherFetchStartVariant::AlreadyCompleted));
            }
            StartInternalWeatherFetchResult::Started(snap) => {
                self.output_port
                    .on_success(map_success(snap, InternalWeatherFetchStartVariant::FetchStarted));
            }
            StartInternalWeatherFetchResult::NeedsFetch(snap) => {
                let started = self
                    .start_farm_weather_data_fetch
                    .call(snap.farm_id, self.calendar_today);
                let snap = WeatherFetchFarmSnapshot {
                    farm_id: snap.farm_id,
                    weather_data_status: started
                        .as_ref()
                        .map(|s| s.weather_data_status.clone())
                        .unwrap_or_else(|| "fetching".to_string()),
                    weather_data_count: snap.weather_data_count,
                    total_blocks: started
                        .map(|s| s.weather_data_total_years)
                        .unwrap_or(snap.total_blocks),
                };
                self.output_port
                    .on_success(map_success(snap, InternalWeatherFetchStartVariant::FetchStarted));
            }
            StartInternalWeatherFetchResult::Failed(message) => {
                self.output_port.on_failure(InternalWeatherFetchFailure {
                    message,
                    http_status: InternalWeatherFetchHttpStatus::InternalServerError,
                });
            }
        }
    }
}

fn map_success(
    snap: WeatherFetchFarmSnapshot,
    variant: InternalWeatherFetchStartVariant,
) -> InternalWeatherFetchStartOutput {
    InternalWeatherFetchStartOutput {
        variant,
        farm_id: snap.farm_id,
        weather_data_status: snap.weather_data_status,
        weather_data_count: snap.weather_data_count,
        total_blocks: snap.total_blocks,
    }
}

#[cfg(test)]
mod interactors_internal_weather_fetch_start_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/interactors_internal_weather_fetch_start_interactor_test.rs"));
}
