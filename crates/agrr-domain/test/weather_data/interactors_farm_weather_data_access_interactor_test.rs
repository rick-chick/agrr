// Tests for `interactors/farm_weather_data_access_interactor.rs` (Ruby parity under test/domain/weather_data/).

    use crate::shared::ports::ClockPort;
    use time::{Date, Month, OffsetDateTime, Time};

    use crate::weather_data::ports::{
        FarmWeatherDataAccessOutputPort, FarmWeatherFarmSummary, FarmWeatherIndexRow,
        FarmWeatherPeriod, FarmWeatherPredictionPeriod, PredictWeatherStandaloneEnqueueResult,
    };
    use std::sync::{Arc, Mutex};

    struct RecordingOutputPort {
        calls: Arc<Mutex<Vec<String>>>,
        last_index: Arc<Mutex<Option<FarmWeatherIndexRow>>>,
    }

    impl FarmWeatherDataAccessOutputPort for RecordingOutputPort {
        fn on_index_success(
            &mut self,
            _: FarmWeatherFarmSummary,
            _: FarmWeatherPeriod,
            data: Vec<FarmWeatherIndexRow>,
        ) {
            self.calls.lock().expect("lock").push("index_success".into());
            if let Some(row) = data.into_iter().next() {
                *self.last_index.lock().expect("lock") = Some(row);
            }
        }

        fn on_prediction_cached_success(
            &mut self,
            _: FarmWeatherFarmSummary,
            _: FarmWeatherPredictionPeriod,
            _: bool,
            _: Option<String>,
            _: Option<String>,
            _: Vec<FarmWeatherIndexRow>,
        ) {
        }

        fn on_prediction_queued(&mut self, _: i64, _: String) {}
        fn on_farm_not_found(&mut self) {
            self.calls.lock().expect("lock").push("farm_not_found".into());
        }
        fn on_no_weather_location(&mut self) {}
        fn on_insufficient_historical_data(&mut self) {}
        fn on_enqueue_failed(&mut self, _: String) {}
    }

    struct FakeFarmGateway {
        ctx: Option<FarmWeatherDataAccessContext>,
    }

    impl WeatherDataFarmGateway for FakeFarmGateway {
        fn farm_weather_data_access_context_for_owned_farm(
            &self,
            _: i64,
            _: i64,
        ) -> Option<FarmWeatherDataAccessContext> {
            self.ctx.clone()
        }

        fn farm_weather_data_access_context_for_admin_lookup(
            &self,
            _: i64,
        ) -> Option<FarmWeatherDataAccessContext> {
            self.ctx.clone()
        }

        fn update_predicted_weather_data(
            &self,
            _: i64,
            _: Option<serde_json::Value>,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<crate::weather_data::gateways::FetchWeatherFarmEntity, crate::shared::exceptions::RecordNotFoundError>
        {
            Err(crate::shared::exceptions::RecordNotFoundError)
        }

        fn update_weather_location_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    struct FakeWeatherGateway {
        rows: Vec<WeatherData>,
    }

    impl WeatherDataGateway for FakeWeatherGateway {
        fn weather_data_for_period(&self, _: i64, _: Date, _: Date) -> Vec<WeatherData> {
            self.rows.clone()
        }

        fn weather_data_count(&self, _: i64, start: Option<Date>, end: Option<Date>) -> i64 {
            if start.is_some() && end.is_some() {
                1
            } else {
                0
            }
        }

        fn historical_data_count(&self, _: i64, _: Date, _: Date) -> i64 {
            10_000
        }

        fn earliest_date(&self, _: i64) -> Option<Date> {
            Some(Date::from_calendar_date(2020, Month::January, 1).expect("valid"))
        }

        fn latest_date(&self, _: i64) -> Option<Date> {
            Some(Date::from_calendar_date(2024, Month::January, 1).expect("valid"))
        }

        fn upsert_weather_data(
            &self,
            _: &[WeatherData],
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }

        fn find_by_coordinates(
            &self,
            _: f64,
            _: f64,
        ) -> Option<crate::weather_data::gateways::WeatherLocationRecord> {
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
            _: i64,
            _: &serde_json::Value,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    struct FakeEnqueue;
    impl PredictWeatherStandaloneEnqueuePort for FakeEnqueue {
        fn enqueue_predict_weather_standalone(
            &self,
            _: i64,
            _: Option<i32>,
            _: &str,
            _: Option<Date>,
            _: Option<i64>,
            _: Option<&str>,
        ) -> PredictWeatherStandaloneEnqueueResult {
            PredictWeatherStandaloneEnqueueResult::success()
        }
    }

    struct FakeParse;
    impl FarmWeatherPredictionPayloadParsePort for FakeParse {
        fn predicted_at_from_payload(&self, _: Option<&str>) -> Option<OffsetDateTime> {
            Some(OffsetDateTime::new_utc(
                Date::from_calendar_date(2026, Month::January, 1).expect("valid"),
                Time::MIDNIGHT,
            ))
        }

        fn prediction_start_date_from_payload(&self, _: Option<&str>) -> Option<Date> {
            Some(Date::from_calendar_date(2026, Month::January, 1).expect("valid"))
        }
    }

    struct FixedClock {
        now: OffsetDateTime,
        today: Date,
    }

    impl ClockPort for FixedClock {
        fn today(&self) -> Date {
            self.today
        }

        fn now(&self) -> OffsetDateTime {
            self.now
        }
    }

    #[test]
    fn index_builds_temperature_mean_from_max_min_when_dto_mean_is_nil() {
        let calls = Arc::new(Mutex::new(Vec::new()));
        let last_index = Arc::new(Mutex::new(None));
        let mut output = RecordingOutputPort {
            calls: calls.clone(),
            last_index: last_index.clone(),
        };
        let farm_gateway = FakeFarmGateway {
            ctx: Some(FarmWeatherDataAccessContext {
                farm_id: 1,
                display_name: "テスト".into(),
                latitude: 35.0,
                longitude: 139.0,
                weather_location_id: Some(9),
                predicted_weather_data: None,
            }),
        };
        let weather_gateway = FakeWeatherGateway {
            rows: vec![WeatherData::new(
                Date::from_calendar_date(2024, Month::June, 1).expect("valid"),
                Some(30.0),
                Some(20.0),
                None,
                Some(1.0),
                None,
                None,
                None,
            )],
        };
        let clock = FixedClock {
            now: OffsetDateTime::new_utc(
                Date::from_calendar_date(2026, Month::January, 1).expect("valid"),
                Time::MIDNIGHT,
            ),
            today: Date::from_calendar_date(2026, Month::January, 1).expect("valid"),
        };
        let mut interactor = FarmWeatherDataAccessInteractor::new(
            &mut output,
            &farm_gateway,
            &weather_gateway,
            &FakeEnqueue,
            &FakeParse,
            &clock,
        );

        interactor.call(FarmWeatherDataAccessInput {
            farm_id: 1,
            user_id: 1,
            is_admin: false,
            predict: false,
            start_date: Some(Date::from_calendar_date(2024, Month::January, 1).expect("valid")),
            end_date: Some(Date::from_calendar_date(2024, Month::December, 31).expect("valid")),
        });

        assert_eq!(calls.lock().expect("lock")[0], "index_success");
        let row = last_index.lock().expect("lock").clone().expect("row");
        assert!((row.temperature_mean - 25.0).abs() < f64::EPSILON);
    }

    #[test]
    fn returns_farm_not_found_when_gateway_returns_nil() {
        let calls = Arc::new(Mutex::new(Vec::new()));
        let mut output = RecordingOutputPort {
            calls: calls.clone(),
            last_index: Arc::new(Mutex::new(None)),
        };
        let farm_gateway = FakeFarmGateway { ctx: None };
        let weather_gateway = FakeWeatherGateway { rows: vec![] };
        let clock = FixedClock {
            now: OffsetDateTime::new_utc(
                Date::from_calendar_date(2026, Month::January, 1).expect("valid"),
                Time::MIDNIGHT,
            ),
            today: Date::from_calendar_date(2026, Month::January, 1).expect("valid"),
        };
        let mut interactor = FarmWeatherDataAccessInteractor::new(
            &mut output,
            &farm_gateway,
            &weather_gateway,
            &FakeEnqueue,
            &FakeParse,
            &clock,
        );

        interactor.call(FarmWeatherDataAccessInput {
            farm_id: 99,
            user_id: 1,
            is_admin: false,
            predict: false,
            start_date: None,
            end_date: None,
        });

        assert_eq!(calls.lock().expect("lock")[0], "farm_not_found");
    }
