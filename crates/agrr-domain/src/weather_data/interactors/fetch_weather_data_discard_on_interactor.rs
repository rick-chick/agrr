//! Ruby: `Domain::WeatherData::Interactors::FetchWeatherDataDiscardOnInteractor`

use std::collections::BTreeMap;

use crate::shared::ports::{LoggerPort, TranslatorPort};
use crate::weather_data::dtos::FetchWeatherDataDiscardOnInput;
use crate::weather_data::ports::{FetchWeatherDataJobPresenterPort, MarkFarmWeatherDataFailedPort};

/// Ruby: `Domain::WeatherData::Interactors::FetchWeatherDataDiscardOnInteractor`
pub struct FetchWeatherDataDiscardOnInteractor<'a, T> {
    presenter: &'a dyn FetchWeatherDataJobPresenterPort,
    logger: &'a dyn LoggerPort,
    translator: &'a T,
    mark_failed: &'a dyn MarkFarmWeatherDataFailedPort,
}

impl<'a, T> FetchWeatherDataDiscardOnInteractor<'a, T>
where
    T: TranslatorPort,
{
    pub fn new(
        presenter: &'a dyn FetchWeatherDataJobPresenterPort,
        logger: &'a dyn LoggerPort,
        translator: &'a T,
        mark_failed: &'a dyn MarkFarmWeatherDataFailedPort,
    ) -> Self {
        Self {
            presenter,
            logger,
            translator,
            mark_failed,
        }
    }

    pub fn call(&self, input: FetchWeatherDataDiscardOnInput) {
        let farm_id = input.farm_id;
        let period_str = period_label(input.start_date, input.end_date);

        self.presenter.error(&format!(
            "❌ [Farm#{:?}] Invalid data for {period_str}: {}",
            farm_id, input.error_message
        ));

        let mut options = BTreeMap::new();
        options.insert("error".to_string(), input.error_message.clone());
        let error_msg = self
            .translator
            .t("jobs.fetch_weather_data.validation_error", &options);

        if let Some(farm_id) = farm_id {
            self.mark_failed.call(farm_id, &error_msg);
        }

        let _ = self.logger;
    }
}

fn period_label(start_date: time::Date, end_date: time::Date) -> String {
    if start_date.year() == end_date.year() {
        start_date.year().to_string()
    } else {
        format!("{}-{}", start_date.year(), end_date.year())
    }
}

#[cfg(test)]
mod interactors_fetch_weather_data_discard_on_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/interactors_fetch_weather_data_discard_on_interactor_test.rs"));
}
