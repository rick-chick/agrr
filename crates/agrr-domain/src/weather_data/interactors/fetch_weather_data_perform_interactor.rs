//! Ruby: `Domain::WeatherData::Interactors::FetchWeatherDataPerformInteractor`

use serde_json::Value;
use time::Date;

use crate::shared::exceptions::RecordNotFoundError;
use crate::weather_data::dtos::{FetchWeatherDataPerformInput, WeatherData};
use crate::weather_data::gateways::{
    AgrrWeatherGateway, WeatherDataFarmGateway, WeatherDataGateway,
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
    ExcessiveMissingWeatherDays,
    MissingOrInvalidWeatherLocation,
    InvalidDateParameters,
    WeatherDataStorageFailed(String),
}

impl std::fmt::Display for FetchWeatherDataPerformError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::WeatherDataStorageFailed(msg) => write!(f, "{msg}"),
            other => write!(f, "{other:?}"),
        }
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
    ) -> Self {
        Self {
            weather_data_gateway,
            farm_gateway,
            advance_phase,
            record_block_completed,
            agrr_weather_gateway,
            presenter,
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
            let existing_count = self
                .weather_data_gateway
                .weather_data_count(
                    location.id,
                    Some(input.start_date),
                    Some(input.end_date),
                )
                .map_err(|e| {
                    FetchWeatherDataPerformError::WeatherDataStorageFailed(e.to_string())
                })?;
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
            return self.complete_fetch_without_new_data(&input);
        };

        let data_points = weather_data
            .get("data")
            .and_then(|v| v.as_array())
            .ok_or(FetchWeatherDataPerformError::InvalidWeatherDataArray)?;

        let expected_days = (input.end_date - input.start_date).whole_days() + 1;
        let actual_days = data_points.len() as i64;
        let missing_days = (expected_days - actual_days).max(0);
        let allowed_missing_days = (expected_days as f64 * ALLOWED_MISSING_RATIO).ceil() as i64;

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
            self.weather_data_gateway
                .upsert_weather_data(&dtos, weather_location.id)
                .map_err(|e| {
                    FetchWeatherDataPerformError::WeatherDataStorageFailed(e.to_string())
                })?;
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
            if farm.region.as_deref() == Some("in") {
                return "nasa-power".to_string();
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

    /// agrr normal fetch exit 0 with no output file: keep existing store and continue the chain.
    fn complete_fetch_without_new_data(
        &self,
        input: &FetchWeatherDataPerformInput,
    ) -> Result<(), FetchWeatherDataPerformError> {
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
mod interactors_fetch_weather_data_perform_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/interactors_fetch_weather_data_perform_interactor_test.rs"));
}
