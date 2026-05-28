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
            if key == "jobs.fetch_weather_data.validation_error" {
                format!(
                    "データ検証エラー: {}",
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
        let translator = MockTranslator;
        let interactor = FetchWeatherDataDiscardOnInteractor::new(
            &presenter,
            &NoopLogger,
            &translator,
            &mark_failed,
        );

        interactor.call(FetchWeatherDataDiscardOnInput {
            farm_id: Some(1),
            start_date: Date::from_calendar_date(2025, Month::January, 1).expect("valid"),
            end_date: Date::from_calendar_date(2025, Month::January, 7).expect("valid"),
            error_message: "Invalid record".into(),
        });

        let msgs = errors.lock().expect("lock");
        assert!(msgs[0].contains("Invalid data"));
        assert!(msgs[0].contains("Invalid record"));
        assert!(*called.lock().expect("lock"));
    }
}
