//! Ruby: `Domain::WeatherData::Interactors::FetchWeatherDataRetryOnInteractor`

use std::collections::BTreeMap;

use crate::shared::ports::{LoggerPort, TranslatorPort};
use crate::weather_data::dtos::FetchWeatherDataRetryOnInput;
use crate::weather_data::ports::{
    AdvanceCultivationPlanPhasePort, FetchWeatherDataJobPresenterPort,
    MarkFarmWeatherDataFailedPort,
};

/// Ruby: `Domain::WeatherData::Interactors::FetchWeatherDataRetryOnInteractor`
pub struct FetchWeatherDataRetryOnInteractor<'a, T> {
    presenter: &'a dyn FetchWeatherDataJobPresenterPort,
    advance_phase: &'a dyn AdvanceCultivationPlanPhasePort,
    mark_failed: &'a dyn MarkFarmWeatherDataFailedPort,
    logger: &'a dyn LoggerPort,
    translator: &'a T,
}

impl<'a, T> FetchWeatherDataRetryOnInteractor<'a, T>
where
    T: TranslatorPort,
{
    pub fn new(
        presenter: &'a dyn FetchWeatherDataJobPresenterPort,
        advance_phase: &'a dyn AdvanceCultivationPlanPhasePort,
        mark_failed: &'a dyn MarkFarmWeatherDataFailedPort,
        logger: &'a dyn LoggerPort,
        translator: &'a T,
    ) -> Self {
        Self {
            presenter,
            advance_phase,
            mark_failed,
            logger,
            translator,
        }
    }

    pub fn call(&self, input: FetchWeatherDataRetryOnInput) {
        let farm_id = input.farm_id;
        let period_str = period_label(input.start_date, input.end_date);

        self.presenter.error(&format!(
            "❌ [Farm#{:?}] Failed to fetch weather data for {period_str} after {} attempts",
            farm_id, input.executions
        ));
        self.presenter
            .error(&format!("   Final error: {}", input.error_message));

        let mut options = BTreeMap::new();
        options.insert("error".to_string(), input.error_message.clone());
        let error_msg = self
            .translator
            .t("jobs.fetch_weather_data.retry_limit_exceeded", &options);

        if let Some(farm_id) = farm_id {
            self.mark_failed.call(farm_id, &error_msg);
        }

        if let (Some(plan_id), Some(channel)) =
            (input.cultivation_plan_id, input.channel_class.as_deref())
        {
            self.advance_phase
                .call_failed_fetching_weather(plan_id, channel);
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
mod interactors_fetch_weather_data_retry_on_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/interactors_fetch_weather_data_retry_on_interactor_test.rs"));
}
