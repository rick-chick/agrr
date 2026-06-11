// Tests for `interactors/weather_prediction_interactor.rs` (Ruby parity under test/domain/weather_data/).

    use crate::shared::ports::ClockPort;
    use time::{Date, Month, OffsetDateTime, Time};

    use crate::weather_data::dtos::{
        CultivationPlanWeather, PredictedWeatherMetadata, PredictedWeatherScope, WeatherPredictionAnchors,
    };
    use crate::weather_data::gateways::{
        PredictedWeatherMetadataGateway, PredictedWeatherStoreGateway,
    };
    use crate::weather_data::helpers::build_metadata_from_payload;
    use serde_json::json;
    use std::collections::HashMap;
    use std::sync::{Arc, Mutex};

    type ScopeKey = (PredictedWeatherScope, i64);

    struct FakePredictedWeatherStore {
        metadata_gateway: FakeMetadataGateway,
        store_gateway: FakeStoreGateway,
    }

    impl FakePredictedWeatherStore {
        fn new() -> Self {
            let metadata = Arc::new(Mutex::new(HashMap::new()));
            let payloads = Arc::new(Mutex::new(HashMap::new()));
            Self {
                metadata_gateway: FakeMetadataGateway {
                    metadata: metadata.clone(),
                },
                store_gateway: FakeStoreGateway { payloads },
            }
        }

        fn seed(
            &self,
            scope: PredictedWeatherScope,
            scope_id: i64,
            payload: Value,
            target_end_date: Date,
        ) {
            let generated_at = "1".to_string();
            let meta = build_metadata_from_payload(
                scope,
                scope_id,
                &payload,
                target_end_date,
                generated_at,
            )
            .expect("metadata");
            self.metadata_gateway
                .metadata
                .lock()
                .expect("lock")
                .insert((scope, scope_id), meta);
            self.store_gateway
                .payloads
                .lock()
                .expect("lock")
                .insert((scope, scope_id), payload);
        }

        fn location_payload(&self) -> Option<Value> {
            self.store_gateway
                .payloads
                .lock()
                .expect("lock")
                .get(&(PredictedWeatherScope::Location, 1))
                .cloned()
        }

        fn plan_payload(&self, plan_id: i64) -> Option<Value> {
            self.store_gateway
                .payloads
                .lock()
                .expect("lock")
                .get(&(PredictedWeatherScope::Plan, plan_id))
                .cloned()
        }
    }

    struct FakeMetadataGateway {
        metadata: Arc<Mutex<HashMap<ScopeKey, PredictedWeatherMetadata>>>,
    }

    impl PredictedWeatherMetadataGateway for FakeMetadataGateway {
        fn find(
            &self,
            scope: PredictedWeatherScope,
            scope_id: i64,
        ) -> Result<Option<PredictedWeatherMetadata>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self
                .metadata
                .lock()
                .expect("lock")
                .get(&(scope, scope_id))
                .cloned())
        }

        fn upsert(
            &self,
            metadata: &PredictedWeatherMetadata,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            self.metadata
                .lock()
                .expect("lock")
                .insert((metadata.scope, metadata.scope_id), metadata.clone());
            Ok(())
        }

        fn copy_plan_metadata(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    struct FakeStoreGateway {
        payloads: Arc<Mutex<HashMap<ScopeKey, Value>>>,
    }

    impl PredictedWeatherStoreGateway for FakeStoreGateway {
        fn read_payload(
            &self,
            scope: PredictedWeatherScope,
            scope_id: i64,
        ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self
                .payloads
                .lock()
                .expect("lock")
                .get(&(scope, scope_id))
                .cloned())
        }

        fn write_payload(
            &self,
            scope: PredictedWeatherScope,
            scope_id: i64,
            payload: &Value,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            self.payloads
                .lock()
                .expect("lock")
                .insert((scope, scope_id), payload.clone());
            Ok(())
        }

        fn copy_plan_payload(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

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
    }

    impl WeatherDataGateway for FakeWeatherDataGateway {
        fn weather_data_for_period(
            &self,
            _: i64,
            _: Date,
            _: Date,
        ) -> Result<Vec<WeatherData>, crate::weather_data::gateways::WeatherDataStorageError> {
            Ok(self.period_data.clone())
        }

        fn weather_data_count(
            &self,
            _: i64,
            _: Option<Date>,
            _: Option<Date>,
        ) -> Result<i64, crate::weather_data::gateways::WeatherDataStorageError> {
            Ok(0)
        }

        fn historical_data_count(
            &self,
            _: i64,
            _: Date,
            _: Date,
        ) -> Result<i64, crate::weather_data::gateways::WeatherDataStorageError> {
            Ok(0)
        }

        fn earliest_date(
            &self,
            _: i64,
        ) -> Result<Option<Date>, crate::weather_data::gateways::WeatherDataStorageError> {
            Ok(None)
        }

        fn latest_date(
            &self,
            _: i64,
        ) -> Result<Option<Date>, crate::weather_data::gateways::WeatherDataStorageError> {
            Ok(None)
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

    struct SpyPredictionGateway {
        calls: Arc<Mutex<u32>>,
    }

    impl SpyPredictionGateway {
        fn new() -> Self {
            Self {
                calls: Arc::new(Mutex::new(0)),
            }
        }
    }

    impl PredictionGateway for SpyPredictionGateway {
        fn predict(
            &self,
            _: &Value,
            days: i64,
            _: &str,
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            *self.calls.lock().expect("lock") += 1;
            let mut rows = Vec::new();
            let start = Date::from_calendar_date(2026, Month::May, 14).expect("valid");
            for i in 0..days.max(1) {
                let d = start + time::Duration::days(i);
                rows.push(json!({
                    "time": d.to_string(),
                    "temperature_2m_max": 20.0,
                    "temperature_2m_min": 10.0,
                    "temperature_2m_mean": 15.0,
                    "precipitation_sum": 0.0
                }));
            }
            Ok(json!({ "data": rows }))
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

    fn weather_location_dto() -> WeatherLocation {
        WeatherLocation::new(1, 35.0, 139.0, Some(0.0), Some("Asia/Tokyo".to_string()))
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
        let predicted = FakePredictedWeatherStore::new();
        let weather_gateway = FakeWeatherDataGateway {
            period_data: vec![],
        };
        let bad_clock = BadClock;
        let err = WeatherPredictionInteractor::new(
            weather_location_dto(),
            &predicted.metadata_gateway,
            &predicted.store_gateway,
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
        let predicted = FakePredictedWeatherStore::new();
        let target = Date::from_calendar_date(2025, Month::December, 31).expect("valid");
        predicted.seed(PredictedWeatherScope::Location, 1, payload.clone(), target);
        let weather_gateway = FakeWeatherDataGateway {
            period_data: vec![],
        };
        let clock = fixed_clock();
        let interactor = WeatherPredictionInteractor::new(
            weather_location_dto(),
            &predicted.metadata_gateway,
            &predicted.store_gateway,
            &weather_gateway,
            &NoopPredictionGateway,
            &NoopLogger,
            &clock,
            &FakeAnchors,
        )
        .expect("valid");

        let result = interactor.get_existing_prediction(
            Some(Date::from_calendar_date(2025, Month::January, 1).expect("valid")),
            None,
        );
        assert!(result.is_some());
        let result = result.expect("result");
        assert_eq!(result.data, payload);
        assert_eq!(result.prediction_start_date, "2025-01-01");
    }

    #[test]
    fn get_existing_prediction_returns_cached_plan_prediction_when_location_cache_misses() {
        let plan_payload = json!({
            "data": [
                {
                    "time": "2025-06-01",
                    "temperature_2m_max": 20.0,
                    "temperature_2m_min": 10.0,
                    "temperature_2m_mean": 15.0,
                    "precipitation_sum": 0.0
                }
            ],
            "prediction_start_date": "2025-01-01",
            "prediction_end_date": "2025-12-31"
        });
        let predicted = FakePredictedWeatherStore::new();
        let target = Date::from_calendar_date(2025, Month::December, 31).expect("valid");
        predicted.seed(PredictedWeatherScope::Plan, 99, plan_payload.clone(), target);
        let plan_weather = CultivationPlanWeather::new(99, None, None, None);
        let weather_gateway = FakeWeatherDataGateway {
            period_data: vec![],
        };
        let clock = fixed_clock();
        let interactor = WeatherPredictionInteractor::new(
            weather_location_dto(),
            &predicted.metadata_gateway,
            &predicted.store_gateway,
            &weather_gateway,
            &NoopPredictionGateway,
            &NoopLogger,
            &clock,
            &FakeAnchors,
        )
        .expect("valid");

        let result = interactor.get_existing_prediction(
            Some(Date::from_calendar_date(2025, Month::June, 1).expect("valid")),
            Some(&plan_weather),
        );
        assert!(result.is_some());
        assert_eq!(result.expect("result").data, plan_payload);
    }

    #[test]
    fn predict_for_cultivation_plan_reuses_location_cache_without_calling_gateway() {
        let cached = json!({
            "data": [{
                "time": "2025-12-31",
                "temperature_2m_max": 99.0,
                "temperature_2m_min": 1.0,
                "temperature_2m_mean": 50.0,
                "precipitation_sum": 0.0
            }],
            "prediction_start_date": "2025-01-01",
            "prediction_end_date": "2025-12-31"
        });
        let spy = SpyPredictionGateway::new();
        let calls = spy.calls.clone();
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
        let predicted = FakePredictedWeatherStore::new();
        let target = Date::from_calendar_date(2025, Month::December, 31).expect("valid");
        predicted.seed(PredictedWeatherScope::Location, 1, cached, target);
        let weather_gateway = FakeWeatherDataGateway {
            period_data: vec![],
        };
        let clock = fixed_clock();
        let interactor = WeatherPredictionInteractor::with_test_overrides(
            weather_location_dto(),
            &predicted.metadata_gateway,
            &predicted.store_gateway,
            &weather_gateway,
            &spy,
            &NoopLogger,
            &clock,
            &FakeAnchors,
            WeatherPredictionTestOverrides {
                training_result: Some(training_result),
                ..Default::default()
            },
        );

        interactor
            .predict_for_cultivation_plan(&plan_weather_dto(), None)
            .expect("ok");

        assert_eq!(
            *calls.lock().expect("lock"),
            0,
            "Rails parity: reuse weather_location cache when it covers target_end_date"
        );
    }

    #[test]
    fn predict_for_cultivation_plan_persists_built_payload_via_both_gateways() {
        let clock = fixed_clock();
        let predicted = FakePredictedWeatherStore::new();
        let weather_gateway = FakeWeatherDataGateway {
            period_data: vec![],
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
            weather_location_dto(),
            &predicted.metadata_gateway,
            &predicted.store_gateway,
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

        let location_payload = predicted.location_payload().expect("persisted");
        assert_eq!(location_payload["model"], "lightgbm");
        assert_eq!(location_payload["prediction_start_date"], "2025-01-01");
        assert_eq!(location_payload["target_end_date"], "2025-12-31");

        let plan_payload = predicted.plan_payload(50).expect("updated");
        assert_eq!(plan_payload, location_payload);
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

        let predicted = FakePredictedWeatherStore::new();
        let weather_gateway = FakeWeatherDataGateway {
            period_data: vec![],
        };

        let interactor = WeatherPredictionInteractor::with_test_overrides(
            weather_location_dto(),
            &predicted.metadata_gateway,
            &predicted.store_gateway,
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

    struct FailingWeatherDataGateway {
        message: String,
    }

    impl WeatherDataGateway for FailingWeatherDataGateway {
        fn weather_data_for_period(
            &self,
            _: i64,
            _: Date,
            _: Date,
        ) -> Result<Vec<WeatherData>, crate::weather_data::gateways::WeatherDataStorageError> {
            Err(crate::weather_data::gateways::WeatherDataStorageError::new(
                self.message.clone(),
            ))
        }

        fn weather_data_count(
            &self,
            _: i64,
            _: Option<Date>,
            _: Option<Date>,
        ) -> Result<i64, crate::weather_data::gateways::WeatherDataStorageError> {
            Ok(0)
        }

        fn historical_data_count(
            &self,
            _: i64,
            _: Date,
            _: Date,
        ) -> Result<i64, crate::weather_data::gateways::WeatherDataStorageError> {
            Ok(0)
        }

        fn earliest_date(
            &self,
            _: i64,
        ) -> Result<Option<Date>, crate::weather_data::gateways::WeatherDataStorageError> {
            Ok(None)
        }

        fn latest_date(
            &self,
            _: i64,
        ) -> Result<Option<Date>, crate::weather_data::gateways::WeatherDataStorageError> {
            Ok(None)
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

    }

    #[test]
    fn predict_surfaces_gateway_storage_error_detail() {
        let predicted = FakePredictedWeatherStore::new();
        let weather_gateway = FailingWeatherDataGateway {
            message: "GCS HTTP 503: backend timeout".into(),
        };
        let clock = fixed_clock();
        let interactor = WeatherPredictionInteractor::new(
            weather_location_dto(),
            &predicted.metadata_gateway,
            &predicted.store_gateway,
            &weather_gateway,
            &NoopPredictionGateway,
            &NoopLogger,
            &clock,
            &FakeAnchors,
        )
        .expect("valid");

        let err = interactor
            .predict_for_cultivation_plan(&plan_weather_dto(), None)
            .expect_err("storage failure");

        assert_eq!(
            err,
            WeatherPredictionError::WeatherDataStorageFailed(
                "GCS HTTP 503: backend timeout".into()
            )
        );
        assert_eq!(err.to_string(), "GCS HTTP 503: backend timeout");
    }
