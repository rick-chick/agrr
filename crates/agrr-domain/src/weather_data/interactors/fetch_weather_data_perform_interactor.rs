//! Ruby: `Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor`

use serde_json::{json, Value};
use time::{Date, OffsetDateTime};

use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::ports::LoggerPort;
use crate::weather_data::dtos::{FetchWeatherDataPerformInput, WeatherData};
use crate::weather_data::gateways::{
    AgrrWeatherGateway, FetchWeatherFarmEntity, WeatherDataFarmGateway, WeatherDataGateway,
    WeatherLocationRecord,
};
use crate::weather_data::helpers::parse_iso_date;
use crate::weather_data::ports::{
    FetchWeatherAdvancePhasePort, FetchWeatherDataJobPresenterPort, FetchWeatherPhase,
    RecordFarmWeatherBlockCompletedPort,
};

const SUFFICIENT_DATA_RATIO: f64 = 0.8;
const ALLOWED_MISSING_RATIO: f64 = 0.05;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum FetchWeatherDataPerformError {
    InvalidWeatherApiResponse,
    InvalidWeatherDataArray,
    EmptyWeatherDataNotAllowed,
    ExcessiveMissingWeatherDays,
    MissingOrInvalidWeatherLocation,
    InvalidDateParameters,
}

impl std::fmt::Display for FetchWeatherDataPerformError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{self:?}")
    }
}

impl std::error::Error for FetchWeatherDataPerformError {}

/// Ruby: `Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor`
pub struct FetchWeatherDataPerformInteractor<'a> {
    weather_data_gateway: &'a dyn WeatherDataGateway,
    farm_gateway: &'a dyn WeatherDataFarmGateway,
    advance_phase: &'a dyn FetchWeatherAdvancePhasePort,
    record_block_completed: &'a dyn RecordFarmWeatherBlockCompletedPort,
    agrr_weather_gateway: &'a dyn AgrrWeatherGateway,
    presenter: &'a dyn FetchWeatherDataJobPresenterPort,
    logger: &'a dyn LoggerPort,
    skip_api_sleep: bool,
}

impl<'a> FetchWeatherDataPerformInteractor<'a> {
    pub fn new(
        weather_data_gateway: &'a dyn WeatherDataGateway,
        farm_gateway: &'a dyn WeatherDataFarmGateway,
        advance_phase: &'a dyn FetchWeatherAdvancePhasePort,
        record_block_completed: &'a dyn RecordFarmWeatherBlockCompletedPort,
        agrr_weather_gateway: &'a dyn AgrrWeatherGateway,
        presenter: &'a dyn FetchWeatherDataJobPresenterPort,
        logger: &'a dyn LoggerPort,
    ) -> Self {
        Self {
            weather_data_gateway,
            farm_gateway,
            advance_phase,
            record_block_completed,
            agrr_weather_gateway,
            presenter,
            logger,
            skip_api_sleep: false,
        }
    }

    #[cfg(test)]
    pub fn with_skip_api_sleep(mut self) -> Self {
        self.skip_api_sleep = true;
        self
    }

    pub fn call(&self, input: FetchWeatherDataPerformInput) -> Result<(), FetchWeatherDataPerformError> {
        if input.start_date > input.end_date {
            return Ok(());
        }

        if input.cultivation_plan_id.is_some() && input.channel_class.is_some() {
            self.advance_phase.call(
                input.cultivation_plan_id.expect("checked"),
                FetchWeatherPhase::FetchingWeather,
                input.channel_class.as_deref().expect("checked"),
            );
        }

        if let Some(location) = self
            .weather_data_gateway
            .find_by_coordinates(input.latitude, input.longitude)
        {
            let expected_days = (input.end_date - input.start_date).whole_days() + 1;
            let existing_count = self.weather_data_gateway.weather_data_count(
                location.id,
                Some(input.start_date),
                Some(input.end_date),
            );
            let threshold_days = (expected_days as f64 * SUFFICIENT_DATA_RATIO).ceil() as i64;

            if existing_count >= threshold_days {
                if let Some(farm_id) = input.farm_id {
                    let _ = self.record_block_completed.call(farm_id, input.current_time);
                }
                return Ok(());
            }
        }

        if !self.skip_api_sleep {
            std::thread::sleep(std::time::Duration::from_millis(500));
        }

        let weather_data = self.fetch_weather_from_agrr(
            input.latitude,
            input.longitude,
            input.start_date,
            input.end_date,
            input.farm_id,
        )?;

        let Some(weather_data) = weather_data else {
            return Err(FetchWeatherDataPerformError::InvalidWeatherApiResponse);
        };

        let data_points = weather_data
            .get("data")
            .and_then(|v| v.as_array())
            .ok_or(FetchWeatherDataPerformError::InvalidWeatherDataArray)?;

        let expected_days = (input.end_date - input.start_date).whole_days() + 1;
        let actual_days = data_points.len() as i64;
        let missing_days = (expected_days - actual_days).max(0);
        let allowed_missing_days = (expected_days as f64 * ALLOWED_MISSING_RATIO).ceil() as i64;

        if data_points.is_empty() {
            return Err(FetchWeatherDataPerformError::EmptyWeatherDataNotAllowed);
        }
        if missing_days > allowed_missing_days {
            return Err(FetchWeatherDataPerformError::ExcessiveMissingWeatherDays);
        } else if missing_days > 0 {
            self.presenter.warn("weather data incomplete");
        }

        let location_data = weather_data
            .get("location")
            .and_then(|v| v.as_object())
            .ok_or(FetchWeatherDataPerformError::MissingOrInvalidWeatherLocation)?;

        let weather_location = self
            .weather_data_gateway
            .find_or_create_weather_location(
                location_data
                    .get("latitude")
                    .and_then(|v| v.as_f64())
                    .unwrap_or(input.latitude),
                location_data
                    .get("longitude")
                    .and_then(|v| v.as_f64())
                    .unwrap_or(input.longitude),
                location_data.get("elevation").and_then(|v| v.as_f64()),
                location_data
                    .get("timezone")
                    .and_then(|v| v.as_str()),
            )
            .map_err(|_| FetchWeatherDataPerformError::MissingOrInvalidWeatherLocation)?;

        if let Some(farm_id) = input.farm_id {
            let _ = self
                .farm_gateway
                .update_weather_location_id(farm_id, weather_location.id);
        }

        let dtos: Vec<WeatherData> = data_points
            .iter()
            .filter_map(|daily| parse_weather_dto(daily))
            .collect();

        if !dtos.is_empty() {
            let _ = self
                .weather_data_gateway
                .upsert_weather_data(&dtos, weather_location.id);
        }

        if let Some(farm_id) = input.farm_id {
            let _ = self.record_block_completed.call(farm_id, input.current_time);
        }

        if input.cultivation_plan_id.is_some() && input.channel_class.is_some() {
            self.advance_phase.call(
                input.cultivation_plan_id.expect("checked"),
                FetchWeatherPhase::WeatherDataFetched,
                input.channel_class.as_deref().expect("checked"),
            );
        }

        Ok(())
    }

    pub fn determine_data_source(
        &self,
        farm_id: Option<i64>,
        latitude: f64,
        longitude: f64,
    ) -> String {
        let farm_entity = farm_id.and_then(|id| match self.farm_gateway.find_by_id(id) {
            Ok(entity) => Some(entity),
            Err(RecordNotFoundError) => None,
        });

        if let Some(farm) = farm_entity {
            if farm.region.as_deref() == Some("jp") {
                return "jma".to_string();
            }
            if japan_location(latitude, longitude) {
                return "jma".to_string();
            }
            if farm.region.is_none() {
                return "nasa-power".to_string();
            }
            return "noaa".to_string();
        }

        if japan_location(latitude, longitude) {
            "jma".to_string()
        } else {
            "noaa".to_string()
        }
    }

    fn fetch_weather_from_agrr(
        &self,
        latitude: f64,
        longitude: f64,
        start_date: Date,
        end_date: Date,
        farm_id: Option<i64>,
    ) -> Result<Option<Value>, FetchWeatherDataPerformError> {
        let data_source = self.determine_data_source(farm_id, latitude, longitude);
        self.agrr_weather_gateway
            .fetch_by_date_range(latitude, longitude, start_date, end_date, &data_source)
            .map_err(|_| FetchWeatherDataPerformError::InvalidWeatherApiResponse)
    }
}

fn japan_location(latitude: f64, longitude: f64) -> bool {
    (24.0..=46.0).contains(&latitude) && (130.0..=146.0).contains(&longitude)
}

fn parse_weather_dto(daily: &Value) -> Option<WeatherData> {
    let date_str = daily.get("time")?.as_str()?;
    let date = parse_iso_date(date_str)?;
    Some(WeatherData::new(
        date,
        daily.get("temperature_2m_max").and_then(|v| v.as_f64()),
        daily.get("temperature_2m_min").and_then(|v| v.as_f64()),
        daily.get("temperature_2m_mean").and_then(|v| v.as_f64()),
        daily.get("precipitation_sum").and_then(|v| v.as_f64()),
        daily.get("sunshine_hours").and_then(|v| v.as_f64()),
        daily.get("wind_speed_10m").and_then(|v| v.as_f64()),
        daily
            .get("weather_code")
            .and_then(|v| v.as_i64())
            .map(|v| v as i32),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::{Arc, Mutex};
    use time::{Month, Time};

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

    struct NoopLogger;
    impl LoggerPort for NoopLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
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
    }

    impl WeatherDataGateway for MockWeatherGateway {
        fn weather_data_for_period(&self, _: i64, _: Date, _: Date) -> Vec<WeatherData> {
            vec![]
        }

        fn weather_data_count(&self, _: i64, start: Option<Date>, end: Option<Date>) -> i64 {
            if start.is_some() && end.is_some() {
                self.weather_count
            } else {
                0
            }
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
        logger: NoopLogger,
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
            Self {
                weather: MockWeatherGateway {
                    find_coords,
                    weather_count,
                    upsert_called,
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
                logger: NoopLogger,
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
                &self.logger,
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
                &self.logger,
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
    fn raises_on_empty_data_response() {
        let empty = json!({
            "location": {
                "latitude": 35.6762,
                "longitude": 139.6503,
                "elevation": 50.0,
                "timezone": "Asia/Tokyo"
            },
            "data": []
        });
        let harness = PerformHarness::new(
            None,
            0,
            Arc::new(Mutex::new(false)),
            Some("jp".into()),
            false,
            Some(empty),
        );

        let err = harness.interactor().call(sample_input()).expect_err("error");
        assert_eq!(err, FetchWeatherDataPerformError::EmptyWeatherDataNotAllowed);
    }

    #[test]
    fn raises_on_nil_response() {
        let harness = PerformHarness::new(
            None,
            0,
            Arc::new(Mutex::new(false)),
            Some("jp".into()),
            false,
            None,
        );

        let err = harness.interactor().call(sample_input()).expect_err("error");
        assert_eq!(err, FetchWeatherDataPerformError::InvalidWeatherApiResponse);
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
}
