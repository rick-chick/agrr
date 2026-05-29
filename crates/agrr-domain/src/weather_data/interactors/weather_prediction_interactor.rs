//! Ruby: `Domain::WeatherData::Interactors::WeatherPredictionInteractor`

use serde_json::{json, Value};
use time::{Date, OffsetDateTime};

use crate::shared::ports::{ClockPort, LoggerPort};
use crate::weather_data::dtos::{CultivationPlanWeather, WeatherData, WeatherLocation};
use crate::weather_data::gateways::{
    CultivationPlanPredictedWeatherGateway, PredictionGateway, WeatherDataGateway,
};
use crate::weather_data::helpers::parse_iso_date;
use crate::weather_data::ports::WeatherPredictionAnchorsPort;

const MINIMUM_REQUIRED_DAYS: usize = 18 * 365;

#[derive(Debug, Clone)]
pub struct PreparedWeatherInfo {
    pub data: Value,
    pub target_end_date: Date,
    pub prediction_start_date: String,
    pub prediction_days: usize,
}

#[derive(Debug, Clone)]
pub struct ExistingPredictionResult {
    pub data: Value,
    pub target_end_date: Date,
    pub prediction_start_date: String,
    pub prediction_days: i64,
}

#[derive(Debug, Clone)]
struct TrainingDataResult {
    data: Vec<WeatherData>,
    end_date: Date,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum WeatherPredictionError {
    ClockRequired,
    AnchorsResolverRequired,
    WeatherLocationRequired,
    WeatherDataNotFound(String),
    InsufficientPredictionData(String),
}

impl std::fmt::Display for WeatherPredictionError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::ClockRequired => write!(f, "clock must respond to today and now"),
            Self::AnchorsResolverRequired => {
                write!(f, "anchors_resolver must respond to anchors_for")
            }
            Self::WeatherLocationRequired => write!(f, "weather_location is required"),
            Self::WeatherDataNotFound(msg) | Self::InsufficientPredictionData(msg) => {
                write!(f, "{msg}")
            }
        }
    }
}

impl std::error::Error for WeatherPredictionError {}

/// Test-only overrides mirroring Ruby Mocha stubs.
#[derive(Default, Clone)]
pub struct WeatherPredictionTestOverrides {
    pub prepare_weather_data: Option<PreparedWeatherInfo>,
    pub training_result: Option<TrainingDataResult>,
    pub prediction_data: Option<Value>,
}

/// Ruby: `Domain::WeatherData::Interactors::WeatherPredictionInteractor`
pub struct WeatherPredictionInteractor<'a> {
    weather_location: WeatherLocation,
    cultivation_plan_gateway: &'a dyn CultivationPlanPredictedWeatherGateway,
    weather_data_gateway: &'a dyn WeatherDataGateway,
    prediction_gateway: &'a dyn PredictionGateway,
    logger: &'a dyn LoggerPort,
    clock: &'a dyn ClockPort,
    anchors_resolver: &'a dyn WeatherPredictionAnchorsPort,
    test_overrides: WeatherPredictionTestOverrides,
}

impl<'a> WeatherPredictionInteractor<'a> {
    pub fn new(
        weather_location: WeatherLocation,
        cultivation_plan_gateway: &'a dyn CultivationPlanPredictedWeatherGateway,
        weather_data_gateway: &'a dyn WeatherDataGateway,
        prediction_gateway: &'a dyn PredictionGateway,
        logger: &'a dyn LoggerPort,
        clock: &'a dyn ClockPort,
        anchors_resolver: &'a dyn WeatherPredictionAnchorsPort,
    ) -> Result<Self, WeatherPredictionError> {
        let _ = clock.today();
        let _ = clock.now();
        let _ = anchors_resolver.anchors_for(clock.today());
        Ok(Self {
            weather_location,
            cultivation_plan_gateway,
            weather_data_gateway,
            prediction_gateway,
            logger,
            clock,
            anchors_resolver,
            test_overrides: WeatherPredictionTestOverrides::default(),
        })
    }

    #[cfg(test)]
    pub fn with_test_overrides(
        weather_location: WeatherLocation,
        cultivation_plan_gateway: &'a dyn CultivationPlanPredictedWeatherGateway,
        weather_data_gateway: &'a dyn WeatherDataGateway,
        prediction_gateway: &'a dyn PredictionGateway,
        logger: &'a dyn LoggerPort,
        clock: &'a dyn ClockPort,
        anchors_resolver: &'a dyn WeatherPredictionAnchorsPort,
        test_overrides: WeatherPredictionTestOverrides,
    ) -> Self {
        Self {
            weather_location,
            cultivation_plan_gateway,
            weather_data_gateway,
            prediction_gateway,
            logger,
            clock,
            anchors_resolver,
            test_overrides,
        }
    }

    pub fn get_existing_prediction(
        &self,
        target_end_date: Option<Date>,
    ) -> Option<ExistingPredictionResult> {
        let target = self.normalize_target_end_date(target_end_date);
        if let Some(result) =
            cached_prediction_result(self.weather_location.predicted_weather_data(), target)
        {
            return Some(result);
        }
        None
    }

    pub fn predict_for_cultivation_plan(
        &self,
        plan_weather: &CultivationPlanWeather,
        target_end_date: Option<Date>,
    ) -> Result<PreparedWeatherInfo, WeatherPredictionError> {
        let default_target = plan_weather
            .prediction_target_end_date
            .or(plan_weather.calculated_planning_end_date);
        let target = self.normalize_target_end_date(target_end_date.or(default_target));

        let weather_info = self.prepare_weather_data(target)?;
        let payload = self.build_prediction_payload(&weather_info, target);

        self.persist_prediction_payload(&payload)?;
        self.cultivation_plan_gateway
            .update_predicted_weather_data(plan_weather.id, &payload)
            .map_err(|e| {
                WeatherPredictionError::InsufficientPredictionData(format!("persist plan: {e}"))
            })?;

        Ok(weather_info)
    }

    fn prepare_weather_data(
        &self,
        target_end_date: Date,
    ) -> Result<PreparedWeatherInfo, WeatherPredictionError> {
        if let Some(ref info) = self.test_overrides.prepare_weather_data {
            return Ok(info.clone());
        }

        let training_result = self.get_training_data()?;
        let training_data = training_result.data;
        let training_end_date = training_result.end_date;
        let current_year_data = self.get_current_year_data();

        let training_formatted = self.format_weather_data_for_agrr(&training_data);
        let future = self.get_prediction_data(&training_formatted, target_end_date, training_end_date)?;
        let current_year_formatted = self.format_weather_data_for_agrr(&current_year_data);
        let merged_data = merge_weather_data(&current_year_formatted, &future);

        let merged_dates: Vec<Date> = merged_data
            .get("data")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|d| parse_date(d.get("time").and_then(|t| t.as_str())))
                    .collect()
            })
            .unwrap_or_default();
        let merged_end_date = merged_dates.iter().copied().max();
        if merged_end_date.is_none_or(|d| d < target_end_date) {
            let message = format!(
                "Merged weather data ends at {:?}, but target_end_date is {target_end_date}. AGRR prediction may be insufficient.",
                merged_end_date
            );
            self.logger.error(&format!("❌ [WeatherPrediction] {message}"));
            return Err(WeatherPredictionError::InsufficientPredictionData(message));
        }

        let today_for_range = self.clock.today();
        let prediction_start_date = if training_end_date + time::Duration::days(1) > today_for_range {
            training_end_date + time::Duration::days(1)
        } else {
            today_for_range
        };

        self.logger
            .info("✅ [WeatherPrediction] Weather data prepared successfully");

        Ok(PreparedWeatherInfo {
            data: merged_data,
            target_end_date,
            prediction_start_date: prediction_start_date.to_string(),
            prediction_days: merged_dates.len(),
        })
    }

    fn get_training_data(&self) -> Result<TrainingDataResult, WeatherPredictionError> {
        if let Some(ref result) = self.test_overrides.training_result {
            return Ok(result.clone());
        }

        let anchors = self.anchors_resolver.anchors_for(self.clock.today());
        let training_data = self.weather_data_gateway.weather_data_for_period(
            self.weather_location.id,
            anchors.training_start_date,
            anchors.training_end_date,
        );

        if training_data.is_empty() {
            return Err(WeatherPredictionError::WeatherDataNotFound(format!(
                "気象データがありません。期間 {} から {} の気象データが見つかりません。",
                anchors.training_start_date, anchors.training_end_date
            )));
        }

        if training_data.len() < MINIMUM_REQUIRED_DAYS {
            return Err(WeatherPredictionError::WeatherDataNotFound(format!(
                "気象データが不足しています。現在 {} 件のデータがありますが、最低 {} 日分（約18年）のデータが必要です。",
                training_data.len(),
                MINIMUM_REQUIRED_DAYS
            )));
        }

        let actual_training_end_date = training_data.iter().map(|d| d.date).max().unwrap();
        Ok(TrainingDataResult {
            data: training_data,
            end_date: actual_training_end_date,
        })
    }

    fn get_current_year_data(&self) -> Vec<WeatherData> {
        let anchors = self.anchors_resolver.anchors_for(self.clock.today());
        self.weather_data_gateway.weather_data_for_period(
            self.weather_location.id,
            anchors.current_year_history_start_date,
            anchors.current_year_history_end_date,
        )
    }

    fn get_prediction_data(
        &self,
        _training_formatted: &Value,
        target_end_date: Date,
        training_end_date: Date,
    ) -> Result<Value, WeatherPredictionError> {
        if let Some(ref data) = self.test_overrides.prediction_data {
            return Ok(data.clone());
        }

        if let Some(cached) =
            cached_future_data(self.weather_location.predicted_weather_data(), target_end_date)
        {
            return Ok(cached);
        }

        let prediction_start_date = training_end_date + time::Duration::days(1);
        let prediction_days = (target_end_date - training_end_date).whole_days();

        self.logger.info(&format!(
            "🔮 [WeatherPrediction] Predicting weather from {prediction_start_date} until {target_end_date} ({prediction_days} days)"
        ));

        let future = self
            .prediction_gateway
            .predict(_training_formatted, prediction_days, "lightgbm")
            .map_err(|e| WeatherPredictionError::InsufficientPredictionData(e.to_string()))?;

        let future_data = future.get("data").and_then(|v| v.as_array()).cloned().unwrap_or_default();
        let actual_prediction_days = future_data.len() as i64;

        if actual_prediction_days < prediction_days {
            return Err(WeatherPredictionError::InsufficientPredictionData(format!(
                "Expected {prediction_days} days from {prediction_start_date} to {target_end_date}, but received {actual_prediction_days} days."
            )));
        }

        Ok(future)
    }

    fn format_weather_data_for_agrr(&self, weather_data: &[WeatherData]) -> Value {
        let wl = &self.weather_location;
        let data: Vec<Value> = weather_data
            .iter()
            .filter_map(|datum| {
                let tmax = datum.temperature_max?;
                let tmin = datum.temperature_min?;
                let temp_mean = datum
                    .temperature_mean
                    .unwrap_or((tmax + tmin) / 2.0);
                Some(json!({
                    "time": datum.date.to_string(),
                    "temperature_2m_max": tmax,
                    "temperature_2m_min": tmin,
                    "temperature_2m_mean": temp_mean,
                    "precipitation_sum": datum.precipitation.unwrap_or(0.0),
                    "sunshine_duration": datum.sunshine_hours.map(|h| h * 3600.0).unwrap_or(0.0),
                    "wind_speed_10m_max": datum.wind_speed.unwrap_or(0.0),
                    "weather_code": datum.weather_code.unwrap_or(0),
                }))
            })
            .collect();

        json!({
            "latitude": wl.latitude,
            "longitude": wl.longitude,
            "elevation": wl.elevation.unwrap_or(0.0),
            "timezone": wl.timezone.clone().unwrap_or_else(|| "UTC".to_string()),
            "data": data,
        })
    }

    fn normalize_target_end_date(&self, target_end_date: Option<Date>) -> Date {
        target_end_date.unwrap_or_else(|| {
            self.anchors_resolver
                .anchors_for(self.clock.today())
                .default_target_end_date
        })
    }

    fn build_prediction_payload(&self, weather_info: &PreparedWeatherInfo, target_end_date: Date) -> Value {
        let mut data = weather_info.data.clone();
        if data.get("data").and_then(|v| v.as_object()).is_some() {
            if let Some(inner) = data.get("data").cloned() {
                if inner.get("data").and_then(|v| v.as_array()).is_some() {
                    data = inner;
                }
            }
        }

        let data_end = latest_payload_date(data.get("data").and_then(|v| v.as_array()));
        let actual_end_date = data_end.unwrap_or(target_end_date);
        let stamped_at = self.clock.now().unix_timestamp().to_string();

        let mut payload = data.as_object().cloned().unwrap_or_default();
        payload.insert("generated_at".to_string(), Value::String(stamped_at.clone()));
        payload.insert("predicted_at".to_string(), Value::String(stamped_at));
        payload.insert(
            "prediction_start_date".to_string(),
            Value::String(weather_info.prediction_start_date.clone()),
        );
        payload.insert(
            "prediction_end_date".to_string(),
            Value::String(actual_end_date.to_string()),
        );
        payload.insert(
            "target_end_date".to_string(),
            Value::String(target_end_date.to_string()),
        );
        payload.insert("model".to_string(), Value::String("lightgbm".to_string()));
        Value::Object(payload)
    }

    fn persist_prediction_payload(&self, payload: &Value) -> Result<(), WeatherPredictionError> {
        self.weather_data_gateway
            .update_predicted_weather_data(self.weather_location.id, payload)
            .map_err(|e| WeatherPredictionError::InsufficientPredictionData(e.to_string()))
    }
}

fn merge_weather_data(historical: &Value, future: &Value) -> Value {
    let mut hist = historical
        .get("data")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let fut = future
        .get("data")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    hist.extend(fut);
    json!({
        "latitude": historical["latitude"].clone(),
        "longitude": historical["longitude"].clone(),
        "elevation": historical["elevation"].clone(),
        "timezone": historical["timezone"].clone(),
        "data": hist,
    })
}

fn cached_prediction_result(payload: Option<&Value>, target_end_date: Date) -> Option<ExistingPredictionResult> {
    let payload = payload?;
    let prediction_start = parse_date(payload.get("prediction_start_date").and_then(|v| v.as_str()))?;
    let prediction_end = parse_date(payload.get("prediction_end_date").and_then(|v| v.as_str()))?;
    let data_array = payload.get("data")?.as_array()?;
    if data_array.is_empty() {
        return None;
    }
    let data_end = latest_payload_date(Some(data_array));

    if prediction_end < target_end_date {
        return None;
    }
    if data_end.is_none_or(|d| d < target_end_date) {
        return None;
    }

    let cached_prediction_days =
        compute_prediction_days(prediction_start, prediction_end.max(target_end_date));
    Some(ExistingPredictionResult {
        data: payload.clone(),
        target_end_date,
        prediction_start_date: payload
            .get("prediction_start_date")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string(),
        prediction_days: cached_prediction_days,
    })
}

fn cached_future_data(payload: Option<&Value>, target_end_date: Date) -> Option<Value> {
    let payload = payload?;
    let prediction_start = parse_date(payload.get("prediction_start_date").and_then(|v| v.as_str()))?;
    let prediction_end = parse_date(payload.get("prediction_end_date").and_then(|v| v.as_str()))?;
    if prediction_end < target_end_date {
        return None;
    }

    let data = payload.get("data")?.as_array()?;
    let filtered: Vec<Value> = data
        .iter()
        .filter_map(|datum| {
            let datum_date = parse_date(
                datum
                    .get("time")
                    .and_then(|v| v.as_str())
                    .or_else(|| datum.get("date").and_then(|v| v.as_str())),
            )?;
            if datum_date < prediction_start || datum_date > target_end_date {
                return None;
            }
            Some(normalize_prediction_datum(datum))
        })
        .collect();

    if filtered.is_empty() {
        return None;
    }
    let data_end = latest_payload_date(Some(&filtered));
    if data_end.is_none_or(|d| d < target_end_date) {
        return None;
    }
    Some(json!({ "data": filtered }))
}

fn normalize_prediction_datum(datum: &Value) -> Value {
    let time = datum
        .get("time")
        .or_else(|| datum.get("date"))
        .cloned()
        .unwrap_or(Value::Null);
    json!({
        "time": time,
        "temperature_2m_max": datum.get("temperature_2m_max").or_else(|| datum.get("temperature_max")).cloned().unwrap_or(Value::Null),
        "temperature_2m_min": datum.get("temperature_2m_min").or_else(|| datum.get("temperature_min")).cloned().unwrap_or(Value::Null),
        "temperature_2m_mean": datum.get("temperature_2m_mean").or_else(|| datum.get("temperature_mean")).cloned().unwrap_or(Value::Null),
        "precipitation_sum": datum.get("precipitation_sum").or_else(|| datum.get("precipitation")).cloned().unwrap_or(json!(0.0)),
        "sunshine_duration": datum.get("sunshine_duration").cloned().unwrap_or(json!(0.0)),
        "wind_speed_10m_max": datum.get("wind_speed_10m_max").or_else(|| datum.get("wind_speed")).cloned().unwrap_or(json!(0.0)),
        "weather_code": datum.get("weather_code").cloned().unwrap_or(json!(0)),
    })
}

fn parse_date(value: Option<&str>) -> Option<Date> {
    value.and_then(parse_iso_date)
}

fn latest_payload_date(data_array: Option<&Vec<Value>>) -> Option<Date> {
    data_array?
        .iter()
        .filter_map(|datum| {
            parse_date(
                datum
                    .get("time")
                    .and_then(|v| v.as_str())
                    .or_else(|| datum.get("date").and_then(|v| v.as_str())),
            )
        })
        .max()
}

fn compute_prediction_days(prediction_start: Date, prediction_end: Date) -> i64 {
    (prediction_end - prediction_start).whole_days() + 1
}

pub fn validate_weather_prediction_dependencies(
    clock: &dyn ClockPort,
    anchors_resolver: &dyn WeatherPredictionAnchorsPort,
    weather_location: Option<&WeatherLocation>,
) -> Result<(), WeatherPredictionError> {
    let _ = clock.today();
    let _ = clock.now();
    let _ = anchors_resolver.anchors_for(clock.today());
    if weather_location.is_none() {
        return Err(WeatherPredictionError::WeatherLocationRequired);
    }
    Ok(())
}

#[cfg(test)]
mod interactors_weather_prediction_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/weather_data/interactors_weather_prediction_interactor_test.rs"));
}
