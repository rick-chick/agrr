//! Cache-hit logic for predicted weather (metadata-only checks + payload helpers).

use serde_json::{json, Value};
use time::Date;

use crate::weather_data::dtos::PredictedWeatherMetadata;
use crate::weather_data::helpers::parse_iso_date;

pub fn metadata_covers_target(metadata: &PredictedWeatherMetadata, target_end_date: Date) -> bool {
    metadata.covers_target(target_end_date)
}

pub fn payload_covers_target(payload: &Value, target_end_date: Date) -> bool {
    cached_prediction_result(Some(payload), target_end_date).is_some()
}

pub fn build_metadata_from_payload(
    scope: crate::weather_data::dtos::PredictedWeatherScope,
    scope_id: i64,
    payload: &Value,
    target_end_date: Date,
    generated_at: String,
) -> Option<PredictedWeatherMetadata> {
    let prediction_start = parse_date(payload.get("prediction_start_date").and_then(|v| v.as_str()))?;
    let prediction_end = parse_date(payload.get("prediction_end_date").and_then(|v| v.as_str()))?;
    let data_array = payload.get("data")?.as_array()?;
    if data_array.is_empty() {
        return None;
    }
    let data_end = latest_payload_date(Some(data_array))?;
    Some(PredictedWeatherMetadata {
        scope,
        scope_id,
        prediction_start_date: prediction_start,
        prediction_end_date: prediction_end,
        target_end_date,
        data_end_date: data_end,
        generated_at,
    })
}

#[derive(Debug, Clone)]
pub struct CachedPredictionPayload {
    pub data: Value,
    pub prediction_start_date: String,
    pub prediction_days: i64,
}

fn cached_prediction_result(payload: Option<&Value>, target_end_date: Date) -> Option<CachedPredictionPayload> {
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
    Some(CachedPredictionPayload {
        data: payload.clone(),
        prediction_start_date: payload
            .get("prediction_start_date")
            .and_then(|v| v.as_str())
            .unwrap_or_default()
            .to_string(),
        prediction_days: cached_prediction_days,
    })
}

pub fn cached_prediction_from_payload(
    payload: &Value,
    target_end_date: Date,
) -> Option<CachedPredictionPayload> {
    cached_prediction_result(Some(payload), target_end_date)
}

pub fn cached_future_data(payload: &Value, target_end_date: Date) -> Option<Value> {
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
