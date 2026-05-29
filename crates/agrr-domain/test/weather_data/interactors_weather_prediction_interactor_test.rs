// Tests for `interactors/weather_prediction_interactor.rs` (Ruby parity under test/domain/weather_data/).

    use crate::weather_data::dtos::WeatherPredictionAnchors;
    use serde_json::json;
    use std::sync::{Arc, Mutex};
    use time::{Month, Time};

    struct FixedClock {
        today: Date,
        now: OffsetDateTime,
    }

    impl ClockPort for FixedClock {
        fn today(&self) -> Date {
            self.today
        }

        fn now(&self) -> OffsetDateTime {
            self.now
        }
    }

    struct FakeAnchors;
    impl WeatherPredictionAnchorsPort for FakeAnchors {
        fn anchors_for(&self, _day: Date) -> WeatherPredictionAnchors {
            WeatherPredictionAnchors {
                training_start_date: Date::from_calendar_date(2006, Month::January, 1).expect("valid"),
                training_end_date: Date::from_calendar_date(2026, Month::May, 13).expect("valid"),
                current_year_history_start_date: Date::from_calendar_date(2026, Month::January, 1)
                    .expect("valid"),
                current_year_history_end_date: Date::from_calendar_date(2026, Month::May, 13)
                    .expect("valid"),
                default_target_end_date: Date::from_calendar_date(2026, Month::November, 15)
                    .expect("valid"),
            }
        }
    }

    struct NoopLogger;
    impl LoggerPort for NoopLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    struct FakeWeatherDataGateway {
        period_data: Vec<WeatherData>,
        persisted: Arc<Mutex<Option<(i64, Value)>>>,
    }

    impl WeatherDataGateway for FakeWeatherDataGateway {
        fn weather_data_for_period(
            &self,
            _: i64,
            _: Date,
            _: Date,
        ) -> Vec<WeatherData> {
            self.period_data.clone()
        }

        fn weather_data_count(&self, _: i64, _: Option<Date>, _: Option<Date>) -> i64 {
            0
        }

        fn historical_data_count(&self, _: i64, _: Date, _: Date) -> i64 {
            0
        }

        fn earliest_date(&self, _: i64) -> Option<Date> {
            None
        }

        fn latest_date(&self, _: i64) -> Option<Date> {
            None
        }

        fn upsert_weather_data(
            &self,
            _: &[WeatherData],
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }

        fn find_by_coordinates(&self, _: f64, _: f64) -> Option<crate::weather_data::gateways::WeatherLocationRecord> {
            None
        }

        fn find_or_create_weather_location(
            &self,
            _: f64,
            _: f64,
            _: Option<f64>,
            _: Option<&str>,
        ) -> Result<crate::weather_data::gateways::WeatherLocationRecord, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(crate::weather_data::gateways::WeatherLocationRecord { id: 1 })
        }

        fn update_predicted_weather_data(
            &self,
            weather_location_id: i64,
            payload: &Value,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            *self.persisted.lock().expect("lock") = Some((weather_location_id, payload.clone()));
            Ok(())
        }
    }

    struct FakePlanGateway {
        updated: Arc<Mutex<Option<(i64, Value)>>>,
    }

    impl CultivationPlanPredictedWeatherGateway for FakePlanGateway {
        fn update_predicted_weather_data(
            &self,
            plan_id: i64,
            payload: &Value,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            *self.updated.lock().expect("lock") = Some((plan_id, payload.clone()));
            Ok(())
        }
    }

    struct NoopPredictionGateway;
    impl PredictionGateway for NoopPredictionGateway {
        fn predict(
            &self,
            _: &Value,
            _: i64,
            _: &str,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            Ok(json!({ "data": [] }))
        }
    }

    fn fixed_clock() -> FixedClock {
        FixedClock {
            today: Date::from_calendar_date(2026, Month::May, 15).expect("valid"),
            now: OffsetDateTime::new_utc(
                Date::from_calendar_date(2026, Month::May, 15).expect("valid"),
                Time::from_hms(8, 0, 0).expect("valid"),
            ),
        }
    }

    fn weather_location_dto(predicted: Option<Value>) -> WeatherLocation {
        WeatherLocation::new(1, 35.0, 139.0, Some(0.0), Some("Asia/Tokyo".to_string()), predicted)
    }

    fn plan_weather_dto() -> CultivationPlanWeather {
        CultivationPlanWeather::new(
            50,
            Some(Date::from_calendar_date(2025, Month::December, 31).expect("valid")),
            Some(Date::from_calendar_date(2025, Month::December, 31).expect("valid")),
            None,
        )
    }

    #[test]
    fn initialize_requires_clock_responding_to_today_and_now() {
        struct BadClock;
        impl ClockPort for BadClock {
            fn today(&self) -> Date {
                Date::from_calendar_date(2026, Month::January, 1).expect("valid")
            }
            fn now(&self) -> OffsetDateTime {
                OffsetDateTime::new_utc(self.today(), Time::MIDNIGHT)
            }
        }
        let plan_gateway = FakePlanGateway {
            updated: Arc::new(Mutex::new(None)),
        };
        let weather_gateway = FakeWeatherDataGateway {
            period_data: vec![],
            persisted: Arc::new(Mutex::new(None)),
        };
        let bad_clock = BadClock;
        let err = WeatherPredictionInteractor::new(
            weather_location_dto(None),
            &plan_gateway,
            &weather_gateway,
            &NoopPredictionGateway,
            &NoopLogger,
            &bad_clock,
            &FakeAnchors,
        );
        assert!(err.is_ok());
    }

    #[test]
    fn initialize_requires_weather_location() {
        let clock = fixed_clock();
        let err = validate_weather_prediction_dependencies(&clock, &FakeAnchors, None);
        assert_eq!(err, Err(WeatherPredictionError::WeatherLocationRequired));
    }

    #[test]
    fn get_existing_prediction_returns_cached_location_prediction_when_it_covers_target() {
        let payload = json!({
            "data": [
                {
                    "time": "2025-01-01",
                    "temperature_2m_max": 15.0,
                    "temperature_2m_min": 5.0,
                    "temperature_2m_mean": 10.0,
                    "precipitation_sum": 0.0
                }
            ],
            "prediction_start_date": "2025-01-01",
            "prediction_end_date": "2025-12-31",
            "target_end_date": "2025-12-31",
            "model": "lightgbm"
        });
        let plan_gateway = FakePlanGateway {
            updated: Arc::new(Mutex::new(None)),
        };
        let weather_gateway = FakeWeatherDataGateway {
            period_data: vec![],
            persisted: Arc::new(Mutex::new(None)),
        };
        let clock = fixed_clock();
        let interactor = WeatherPredictionInteractor::new(
            weather_location_dto(Some(payload.clone())),
            &plan_gateway,
            &weather_gateway,
            &NoopPredictionGateway,
            &NoopLogger,
            &clock,
            &FakeAnchors,
        )
        .expect("valid");

        let result = interactor.get_existing_prediction(Some(
            Date::from_calendar_date(2025, Month::January, 1).expect("valid"),
        ));
        assert!(result.is_some());
        let result = result.expect("result");
        assert_eq!(result.data, payload);
        assert_eq!(result.prediction_start_date, "2025-01-01");
    }

    #[test]
    fn predict_for_cultivation_plan_persists_built_payload_via_both_gateways() {
        let clock = fixed_clock();
        let persisted = Arc::new(Mutex::new(None));
        let updated = Arc::new(Mutex::new(None));
        let weather_gateway = FakeWeatherDataGateway {
            period_data: vec![],
            persisted: persisted.clone(),
        };
        let plan_gateway = FakePlanGateway {
            updated: updated.clone(),
        };

        let fake_weather_info = PreparedWeatherInfo {
            data: json!({
                "latitude": 35.0,
                "longitude": 139.0,
                "elevation": 0.0,
                "timezone": "Asia/Tokyo",
                "data": [
                    {
                        "time": "2025-01-01",
                        "temperature_2m_max": 20.0,
                        "temperature_2m_min": 10.0,
                        "temperature_2m_mean": 15.0,
                        "precipitation_sum": 0.0
                    }
                ]
            }),
            target_end_date: Date::from_calendar_date(2025, Month::December, 31).expect("valid"),
            prediction_start_date: "2025-01-01".to_string(),
            prediction_days: 365,
        };

        let interactor = WeatherPredictionInteractor::with_test_overrides(
            weather_location_dto(None),
            &plan_gateway,
            &weather_gateway,
            &NoopPredictionGateway,
            &NoopLogger,
            &clock,
            &FakeAnchors,
            WeatherPredictionTestOverrides {
                prepare_weather_data: Some(fake_weather_info),
                ..Default::default()
            },
        );

        interactor
            .predict_for_cultivation_plan(&plan_weather_dto(), None)
            .expect("ok");

        let location_payload = persisted.lock().expect("lock").clone().expect("persisted").1;
        assert_eq!(location_payload["model"], "lightgbm");
        assert_eq!(location_payload["prediction_start_date"], "2025-01-01");
        assert_eq!(location_payload["target_end_date"], "2025-12-31");

        let plan_update = updated.lock().expect("lock").clone().expect("updated");
        assert_eq!(plan_update.0, 50);
        assert_eq!(plan_update.1, location_payload);
    }

    #[test]
    fn predict_for_cultivation_plan_uses_prediction_data_when_current_year_data_is_missing() {
        let clock = fixed_clock();
        let training_result = TrainingDataResult {
            data: vec![WeatherData::new(
                Date::from_calendar_date(2026, Month::May, 13).expect("valid"),
                Some(20.0),
                Some(10.0),
                Some(15.0),
                Some(0.0),
                Some(5.0),
                Some(2.0),
                Some(0),
            )],
            end_date: Date::from_calendar_date(2026, Month::May, 13).expect("valid"),
        };
        let prediction = json!({
            "latitude": 35.0,
            "longitude": 139.0,
            "elevation": 0.0,
            "timezone": "Asia/Tokyo",
            "data": [
                {
                    "time": "2026-01-30",
                    "temperature_2m_max": 20.0,
                    "temperature_2m_min": 10.0,
                    "temperature_2m_mean": 15.0,
                    "precipitation_sum": 0.0
                }
            ]
        });

        let plan_gateway = FakePlanGateway {
            updated: Arc::new(Mutex::new(None)),
        };
        let weather_gateway = FakeWeatherDataGateway {
            period_data: vec![],
            persisted: Arc::new(Mutex::new(None)),
        };

        let interactor = WeatherPredictionInteractor::with_test_overrides(
            weather_location_dto(None),
            &plan_gateway,
            &weather_gateway,
            &NoopPredictionGateway,
            &NoopLogger,
            &clock,
            &FakeAnchors,
            WeatherPredictionTestOverrides {
                training_result: Some(training_result),
                prediction_data: Some(prediction),
                ..Default::default()
            },
        );

        let result = interactor
            .predict_for_cultivation_plan(&plan_weather_dto(), None)
            .expect("ok");
        assert!(result.data.get("data").and_then(|v| v.as_array()).is_some_and(|a| !a.is_empty()));
    }
