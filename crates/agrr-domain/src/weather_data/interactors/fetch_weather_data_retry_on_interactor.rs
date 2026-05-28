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
mod tests {
    use super::*;
    use std::sync::{Arc, Mutex};
    use time::{Date, Month};

    struct MockPresenter {
        errors: Arc<Mutex<Vec<String>>>,
    }

    impl FetchWeatherDataJobPresenterPort for MockPresenter {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, message: &str) {
            self.errors.lock().expect("lock").push(message.to_string());
        }
        fn debug(&self, _: &str) {}
    }

    struct MockTranslator;
    impl TranslatorPort for MockTranslator {
        fn translate(&self, key: &str, options: &BTreeMap<String, String>) -> String {
            if key == "jobs.fetch_weather_data.retry_limit_exceeded" {
                format!(
                    "リトライ上限に達しました: {}",
                    options.get("error").cloned().unwrap_or_default()
                )
            } else {
                key.to_string()
            }
        }

        fn localize(
            &self,
            _: time::Date,
            _: Option<&str>,
            _: &BTreeMap<String, String>,
        ) -> String {
            String::new()
        }
    }

    struct MockMarkFailed {
        called: Arc<Mutex<bool>>,
    }

    impl MarkFarmWeatherDataFailedPort for MockMarkFailed {
        fn call(&self, _: i64, _: &str) {
            *self.called.lock().expect("lock") = true;
        }
    }

    struct NoopAdvance;
    impl AdvanceCultivationPlanPhasePort for NoopAdvance {
        fn call_failed_fetching_weather(&self, _: i64, _: &str) {}
    }

    struct NoopLogger;
    impl LoggerPort for NoopLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    #[test]
    fn execute_calls_presenter_and_marks_failed() {
        let errors = Arc::new(Mutex::new(Vec::new()));
        let called = Arc::new(Mutex::new(false));
        let presenter = MockPresenter {
            errors: errors.clone(),
        };
        let mark_failed = MockMarkFailed {
            called: called.clone(),
        };
        let advance = NoopAdvance;
        let translator = MockTranslator;
        let interactor = FetchWeatherDataRetryOnInteractor::new(
            &presenter,
            &advance,
            &mark_failed,
            &NoopLogger,
            &translator,
        );

        interactor.call(FetchWeatherDataRetryOnInput {
            farm_id: Some(1),
            start_date: Date::from_calendar_date(2025, Month::January, 1).expect("valid"),
            end_date: Date::from_calendar_date(2025, Month::January, 7).expect("valid"),
            executions: 5,
            error_message: "API error".into(),
            cultivation_plan_id: None,
            channel_class: None,
        });

        let msgs = errors.lock().expect("lock");
        assert!(msgs[0].contains("Failed to fetch"));
        assert!(msgs[0].contains("after 5 attempts"));
        assert!(msgs[1].contains("Final error: API error"));
        assert!(*called.lock().expect("lock"));
    }
}
