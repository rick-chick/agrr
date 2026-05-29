// Tests for `interactors/fetch_weather_data_discard_on_interactor.rs` (Ruby parity under test/domain/weather_data/).

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
