// Tests for `interactors/fetch_weather_data_perform_interactor.rs` (Ruby parity under test/domain/weather_data/).

    use time::{Date, Month, OffsetDateTime, Time};

use serde_json::json;

    use crate::shared::exceptions::RecordNotFoundError;
    use crate::weather_data::gateways::{
        FetchWeatherFarmEntity, WeatherDataStorageError, WeatherLocationRecord,
    };
    use std::sync::{Arc, Mutex};

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

    struct MockAdvance {
        calls: Arc<Mutex<usize>>,
    }

    impl FetchWeatherAdvancePhasePort for MockAdvance {
        fn call(&self, _: i64, _: FetchWeatherPhase, _: &str) {
            *self.calls.lock().expect("lock") += 1;
        }
    }

    struct MockRecordBlock;
    impl RecordFarmWeatherBlockCompletedPort for MockRecordBlock {
        fn call(&self, _: i64, _: OffsetDateTime) -> Option<crate::weather_data::dtos::FarmWeatherProgressSnapshot> {
            Some(crate::weather_data::dtos::FarmWeatherProgressSnapshot {
                weather_data_progress: 50,
                weather_data_fetched_years: 1,
                weather_data_total_years: 2,
            })
        }
    }

    struct MockWeatherGateway {
        find_coords: Option<WeatherLocationRecord>,
        weather_count: i64,
        upsert_called: Arc<Mutex<bool>>,
        count_fails: bool,
        upsert_fails: bool,
    }

    impl WeatherDataGateway for MockWeatherGateway {
        fn weather_data_for_period(
            &self,
            _: i64,
            _: Date,
            _: Date,
        ) -> Result<Vec<WeatherData>, WeatherDataStorageError> {
            Ok(vec![])
        }

        fn weather_data_count(
            &self,
            _: i64,
            start: Option<Date>,
            end: Option<Date>,
        ) -> Result<i64, WeatherDataStorageError> {
            if self.count_fails {
                return Err(WeatherDataStorageError::new("count failed"));
            }
            if start.is_some() && end.is_some() {
                Ok(self.weather_count)
            } else {
                Ok(0)
            }
        }

        fn historical_data_count(
            &self,
            _: i64,
            _: Date,
            _: Date,
        ) -> Result<i64, WeatherDataStorageError> {
            Ok(0)
        }

        fn earliest_date(&self, _: i64) -> Result<Option<Date>, WeatherDataStorageError> {
            Ok(None)
        }

        fn latest_date(&self, _: i64) -> Result<Option<Date>, WeatherDataStorageError> {
            Ok(None)
        }

        fn upsert_weather_data(
            &self,
            _: &[WeatherData],
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            if self.upsert_fails {
                return Err("upsert failed".into());
            }
            *self.upsert_called.lock().expect("lock") = true;
            Ok(())
        }

        fn find_by_coordinates(&self, _: f64, _: f64) -> Option<WeatherLocationRecord> {
            self.find_coords.clone()
        }

        fn find_or_create_weather_location(
            &self,
            _: f64,
            _: f64,
            _: Option<f64>,
            _: Option<&str>,
        ) -> Result<WeatherLocationRecord, Box<dyn std::error::Error + Send + Sync>> {
            Ok(WeatherLocationRecord { id: 1 })
        }

        fn update_predicted_weather_data(
            &self,
            _: i64,
            _: &Value,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    struct MockFarmGateway {
        region: Option<String>,
        find_raises: bool,
    }

    impl WeatherDataFarmGateway for MockFarmGateway {
        fn farm_weather_data_access_context_for_owned_farm(
            &self,
            _: i64,
            _: i64,
        ) -> Option<crate::weather_data::dtos::FarmWeatherDataAccessContext> {
            None
        }

        fn farm_weather_data_access_context_for_admin_lookup(
            &self,
            _: i64,
        ) -> Option<crate::weather_data::dtos::FarmWeatherDataAccessContext> {
            None
        }

        fn update_predicted_weather_data(
            &self,
            _: i64,
            _: Option<Value>,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }

        fn find_by_id(&self, _: i64) -> Result<FetchWeatherFarmEntity, RecordNotFoundError> {
            if self.find_raises {
                Err(RecordNotFoundError)
            } else {
                Ok(FetchWeatherFarmEntity {
                    region: self.region.clone(),
                })
            }
        }

        fn update_weather_location_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    struct MockAgrrGateway {
        response: Option<Value>,
    }

    impl AgrrWeatherGateway for MockAgrrGateway {
        fn fetch_by_date_range(
            &self,
            _: f64,
            _: f64,
            _: Date,
            _: Date,
            _: &str,
        ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.response.clone())
        }
    }

    fn sample_input() -> FetchWeatherDataPerformInput {
        FetchWeatherDataPerformInput {
            latitude: 35.6762,
            longitude: 139.6503,
            start_date: Date::from_calendar_date(2025, Month::January, 1).expect("valid"),
            end_date: Date::from_calendar_date(2025, Month::January, 7).expect("valid"),
            farm_id: Some(1),
            cultivation_plan_id: Some(1),
            channel_class: Some("test".into()),
            executions: 1,
            current_time: OffsetDateTime::new_utc(
                Date::from_calendar_date(2025, Month::January, 1).expect("valid"),
                Time::MIDNIGHT,
            ),
        }
    }

    fn weather_point(day: u8) -> Value {
        json!({
            "time": format!("2025-01-{day:02}"),
            "temperature_2m_max": 20.0,
            "temperature_2m_min": 10.0,
            "temperature_2m_mean": 15.0,
            "precipitation_sum": 0.0,
            "sunshine_hours": 6.0,
            "wind_speed_10m": 3.0,
            "weather_code": 0
        })
    }

    struct PerformHarness {
        weather: MockWeatherGateway,
        farm: MockFarmGateway,
        advance: MockAdvance,
        record: MockRecordBlock,
        agrr: MockAgrrGateway,
        presenter: MockPresenter,
    }

    impl PerformHarness {
        fn new(
            find_coords: Option<WeatherLocationRecord>,
            weather_count: i64,
            upsert_called: Arc<Mutex<bool>>,
            region: Option<String>,
            find_raises: bool,
            agrr_response: Option<Value>,
        ) -> Self {
            Self::with_flags(
                find_coords,
                weather_count,
                upsert_called,
                region,
                find_raises,
                agrr_response,
                false,
                false,
            )
        }

        fn with_flags(
            find_coords: Option<WeatherLocationRecord>,
            weather_count: i64,
            upsert_called: Arc<Mutex<bool>>,
            region: Option<String>,
            find_raises: bool,
            agrr_response: Option<Value>,
            count_fails: bool,
            upsert_fails: bool,
        ) -> Self {
            Self {
                weather: MockWeatherGateway {
                    find_coords,
                    weather_count,
                    upsert_called,
                    count_fails,
                    upsert_fails,
                },
                farm: MockFarmGateway {
                    region,
                    find_raises,
                },
                advance: MockAdvance {
                    calls: Arc::new(Mutex::new(0)),
                },
                record: MockRecordBlock,
                agrr: MockAgrrGateway {
                    response: agrr_response,
                },
                presenter: MockPresenter {
                    errors: Arc::new(Mutex::new(vec![])),
                },
            }
        }

        fn interactor(&self) -> FetchWeatherDataPerformInteractor<'_> {
            FetchWeatherDataPerformInteractor::new(
                &self.weather,
                &self.farm,
                &self.advance,
                &self.record,
                &self.agrr,
                &self.presenter,
            )
            .with_skip_api_sleep()
        }

        fn interactor_no_sleep_skip(&self) -> FetchWeatherDataPerformInteractor<'_> {
            FetchWeatherDataPerformInteractor::new(
                &self.weather,
                &self.farm,
                &self.advance,
                &self.record,
                &self.agrr,
                &self.presenter,
            )
        }
    }

    #[test]
    fn sufficient_data_exists_skips_fetch() {
        let harness = PerformHarness::new(
            Some(WeatherLocationRecord { id: 1 }),
            6,
            Arc::new(Mutex::new(false)),
            Some("jp".into()),
            false,
            None,
        );
        harness.interactor().call(sample_input()).expect("ok");
    }

    #[test]
    fn fetch_and_upsert_success() {
        let upsert_called = Arc::new(Mutex::new(false));
        let data: Vec<Value> = (1..=7).map(weather_point).collect();
        let weather_data = json!({
            "location": {
                "latitude": 35.6762,
                "longitude": 139.6503,
                "elevation": 50.0,
                "timezone": "Asia/Tokyo"
            },
            "data": data
        });
        let harness = PerformHarness::new(
            None,
            0,
            upsert_called.clone(),
            Some("jp".into()),
            false,
            Some(weather_data),
        );

        harness.interactor().call(sample_input()).expect("ok");
        assert!(*upsert_called.lock().expect("lock"));
    }

    #[test]
    fn determine_data_source_returns_jma_for_jp_region_farm() {
        let harness = PerformHarness::new(
            None,
            0,
            Arc::new(Mutex::new(false)),
            Some("jp".into()),
            false,
            None,
        );
        assert_eq!(
            harness.interactor_no_sleep_skip().determine_data_source(Some(1), 35.0, 139.0),
            "jma"
        );
    }

    #[test]
    fn determine_data_source_returns_noaa_for_non_jp_region_farm() {
        let harness = PerformHarness::new(
            None,
            0,
            Arc::new(Mutex::new(false)),
            Some("us".into()),
            false,
            None,
        );
        assert_eq!(
            harness
                .interactor_no_sleep_skip()
                .determine_data_source(Some(1), 40.0, -74.0),
            "noaa"
        );
    }

    #[test]
    fn determine_data_source_returns_nasa_power_for_in_region_farm() {
        let harness = PerformHarness::new(
            None,
            0,
            Arc::new(Mutex::new(false)),
            Some("in".into()),
            false,
            None,
        );
        assert_eq!(
            harness
                .interactor_no_sleep_skip()
                .determine_data_source(Some(1), 28.6, 77.2),
            "nasa-power"
        );
    }

    #[test]
    fn determine_data_source_returns_jma_for_japan_coordinates_no_farm() {
        let harness = PerformHarness::new(
            None,
            0,
            Arc::new(Mutex::new(false)),
            None,
            true,
            None,
        );
        assert_eq!(
            harness.interactor_no_sleep_skip().determine_data_source(None, 35.0, 139.0),
            "jma"
        );
    }

    #[test]
    fn determine_data_source_returns_noaa_for_non_japan_coordinates() {
        let harness = PerformHarness::new(
            None,
            0,
            Arc::new(Mutex::new(false)),
            None,
            true,
            None,
        );
        assert_eq!(
            harness.interactor_no_sleep_skip().determine_data_source(None, 37.0, 127.0),
            "noaa"
        );
    }

    #[test]
    fn determine_data_source_ignores_missing_farm_record_and_falls_back_to_coordinates() {
        let harness = PerformHarness::new(
            None,
            0,
            Arc::new(Mutex::new(false)),
            None,
            true,
            None,
        );
        let interactor = harness.interactor_no_sleep_skip();
        assert_eq!(interactor.determine_data_source(Some(1), 35.0, 139.0), "jma");
        assert_eq!(interactor.determine_data_source(Some(1), 37.0, 127.0), "noaa");
    }

    #[test]
    fn skips_ingest_when_agrr_returns_no_output_with_exit_zero() {
        let upsert_called = Arc::new(Mutex::new(false));
        let harness = PerformHarness::new(
            None,
            0,
            upsert_called.clone(),
            Some("jp".into()),
            false,
            None,
        );

        harness
            .interactor_no_sleep_skip()
            .call(sample_input())
            .expect("gap-fill skip when agrr has no output file");

        assert!(
            !*upsert_called.lock().expect("lock"),
            "must not upsert when agrr reports no new weather payload"
        );
    }

    #[test]
    fn skips_gap_fill_when_jma_has_no_published_days_in_window_yet() {
        let upsert_called = Arc::new(Mutex::new(false));
        let harness = PerformHarness::new(
            Some(WeatherLocationRecord { id: 28 }),
            0,
            upsert_called.clone(),
            Some("jp".into()),
            false,
            None,
        );
        let input = FetchWeatherDataPerformInput {
            latitude: 34.7303,
            longitude: 136.5086,
            start_date: Date::from_calendar_date(2026, Month::June, 10).expect("valid"),
            end_date: Date::from_calendar_date(2026, Month::June, 11).expect("valid"),
            farm_id: Some(28),
            cultivation_plan_id: Some(750),
            channel_class: Some("test".into()),
            executions: 1,
            current_time: OffsetDateTime::new_utc(
                Date::from_calendar_date(2026, Month::June, 11).expect("valid"),
                Time::MIDNIGHT,
            ),
        };

        harness
            .interactor_no_sleep_skip()
            .call(input)
            .expect("reference farm gap-fill skip when JMA has not published requested days");

        assert!(
            !*upsert_called.lock().expect("lock"),
            "existing store through latest date must be used without upsert"
        );
    }

    #[test]
    fn raises_on_non_hash_response() {
        let harness = PerformHarness::new(
            None,
            0,
            Arc::new(Mutex::new(false)),
            Some("jp".into()),
            false,
            Some(json!([])),
        );

        let err = harness.interactor().call(sample_input()).expect_err("error");
        assert_eq!(err, FetchWeatherDataPerformError::InvalidWeatherDataArray);
    }

    #[test]
    fn raises_on_missing_location() {
        let bad = json!({
            "data": (1..=7).map(weather_point).collect::<Vec<_>>(),
            "location": null
        });
        let harness = PerformHarness::new(
            None,
            0,
            Arc::new(Mutex::new(false)),
            Some("jp".into()),
            false,
            Some(bad),
        );

        let err = harness.interactor().call(sample_input()).expect_err("error");
        assert_eq!(
            err,
            FetchWeatherDataPerformError::MissingOrInvalidWeatherLocation
        );
    }

    #[test]
    fn raises_on_excessive_missing_data() {
        let insufficient = json!({
            "location": {
                "latitude": 35.6762,
                "longitude": 139.6503,
                "elevation": 50.0,
                "timezone": "Asia/Tokyo"
            },
            "data": [weather_point(1), weather_point(2)]
        });
        let harness = PerformHarness::new(
            None,
            0,
            Arc::new(Mutex::new(false)),
            Some("jp".into()),
            false,
            Some(insufficient),
        );

        let err = harness.interactor().call(sample_input()).expect_err("error");
        assert_eq!(
            err,
            FetchWeatherDataPerformError::ExcessiveMissingWeatherDays
        );
    }

    #[test]
    fn handles_acceptable_missing_data_and_upserts() {
        let upsert_called = Arc::new(Mutex::new(false));
        let data: Vec<Value> = (1..=6).map(weather_point).collect();
        let acceptable = json!({
            "location": {
                "latitude": 35.6762,
                "longitude": 139.6503,
                "elevation": 50.0,
                "timezone": "Asia/Tokyo"
            },
            "data": data
        });
        let harness = PerformHarness::new(
            None,
            0,
            upsert_called.clone(),
            Some("jp".into()),
            false,
            Some(acceptable),
        );

        harness.interactor().call(sample_input()).expect("ok");
        assert!(*upsert_called.lock().expect("lock"));
    }

    #[test]
    fn fails_when_weather_data_count_errors() {
        let harness = PerformHarness::with_flags(
            Some(WeatherLocationRecord { id: 1 }),
            0,
            Arc::new(Mutex::new(false)),
            Some("jp".into()),
            false,
            None,
            true,
            false,
        );

        let err = harness.interactor().call(sample_input()).expect_err("error");
        assert_eq!(
            err,
            FetchWeatherDataPerformError::WeatherDataStorageFailed("count failed".into())
        );
        assert_eq!(err.to_string(), "count failed");
    }

    #[test]
    fn fails_when_upsert_errors() {
        let acceptable = json!({
            "location": {
                "latitude": 35.6762,
                "longitude": 139.6503,
                "elevation": 50.0,
                "timezone": "Asia/Tokyo"
            },
            "data": (1..=7).map(weather_point).collect::<Vec<_>>()
        });
        let harness = PerformHarness::with_flags(
            None,
            0,
            Arc::new(Mutex::new(false)),
            Some("jp".into()),
            false,
            Some(acceptable),
            false,
            true,
        );

        let err = harness.interactor().call(sample_input()).expect_err("error");
        assert_eq!(
            err,
            FetchWeatherDataPerformError::WeatherDataStorageFailed("upsert failed".into())
        );
        assert_eq!(err.to_string(), "upsert failed");
    }
