use serde_json::{json, Map, Value};
use time::Date;

use crate::field_cultivation::helpers::parse_iso_date;
use crate::field_cultivation::dtos::{
    ClimateObservedWeatherDatum, FieldCultivationClimateSourceSnapshot,
};
use crate::shared::validation::to_array_value;

pub fn coerce_optional_date(value: &str) -> Option<Date> {
    if value.trim().is_empty() {
        return None;
    }
    parse_iso_date(value)
}

pub fn build_observed_agrr_payload(
    weather_location_meta: &WeatherLocationMeta,
    observed_weather_dtos: &[ClimateObservedWeatherDatum],
) -> Value {
    let data: Vec<Value> = observed_weather_dtos
        .iter()
        .filter_map(|datum| {
            let max = datum.temperature_max?;
            let min = datum.temperature_min?;
            let temp_mean = datum
                .temperature_mean
                .unwrap_or((max + min) / 2.0);
            Some(json!({
                "time": datum.date.to_string(),
                "temperature_2m_max": max,
                "temperature_2m_min": min,
                "temperature_2m_mean": temp_mean,
                "precipitation_sum": datum.precipitation.unwrap_or(0.0),
                "sunshine_duration": datum.sunshine_hours.map(|h| h * 3600.0).unwrap_or(0.0),
                "wind_speed_10m_max": datum.wind_speed.unwrap_or(0.0),
                "weather_code": datum.weather_code.unwrap_or(0),
            }))
        })
        .collect();
    json!({
        "latitude": weather_location_meta.latitude,
        "longitude": weather_location_meta.longitude,
        "elevation": weather_location_meta.elevation,
        "timezone": weather_location_meta.timezone,
        "data": data,
    })
}

pub fn build_observed_agrr_payload_simple(
    weather_location_meta: &WeatherLocationMeta,
    observed_weather_dtos: &[ClimateObservedWeatherDatum],
) -> Value {
    let data: Vec<Value> = observed_weather_dtos
        .iter()
        .filter_map(|datum| {
            let max = datum.temperature_max?;
            let min = datum.temperature_min?;
            let temp_mean = datum
                .temperature_mean
                .unwrap_or((max + min) / 2.0);
            Some(json!({
                "time": datum.date.to_string(),
                "temperature_2m_max": max,
                "temperature_2m_min": min,
                "temperature_2m_mean": temp_mean,
                "precipitation_sum": datum.precipitation.unwrap_or(0.0),
            }))
        })
        .collect();
    json!({
        "latitude": weather_location_meta.latitude,
        "longitude": weather_location_meta.longitude,
        "timezone": weather_location_meta.timezone,
        "data": data,
    })
}

pub fn merge_cached_with_observed(
    cached_weather_payload: &Value,
    observed_formatted: &Value,
) -> Value {
    let cached_data = to_array_value(cached_weather_payload.get("data"));
    let observed_data = to_array_value(observed_formatted.get("data"));
    if observed_data.is_empty() {
        return cached_weather_payload.clone();
    }

    let mut merged: Map<String, Value> = Map::new();
    for datum in cached_data {
        if let Some(time) = datum.get("time").and_then(|v| v.as_str()) {
            merged.insert(time.to_string(), datum);
        }
    }
    for datum in observed_data {
        if let Some(time) = datum.get("time").and_then(|v| v.as_str()) {
            merged.insert(time.to_string(), datum);
        }
    }

    let mut sorted: Vec<Value> = merged.into_values().collect();
    sorted.sort_by(|a, b| {
        let ta = a.get("time").and_then(|v| v.as_str()).unwrap_or("");
        let tb = b.get("time").and_then(|v| v.as_str()).unwrap_or("");
        ta.cmp(tb)
    });

    let mut out = cached_weather_payload
        .as_object()
        .cloned()
        .unwrap_or_default();
    out.insert("data".into(), Value::Array(sorted));
    Value::Object(out)
}

pub fn merge_training_and_future(training_formatted: &Value, future_payload: &Value) -> Value {
    let mut merged = to_array_value(training_formatted.get("data"));
    merged.extend(to_array_value(future_payload.get("data")));
    json!({
        "latitude": training_formatted.get("latitude").cloned().unwrap_or(Value::Null),
        "longitude": training_formatted.get("longitude").cloned().unwrap_or(Value::Null),
        "timezone": training_formatted.get("timezone").cloned().unwrap_or(Value::Null),
        "data": merged,
    })
}

pub fn valid_weather_payload(weather_payload: Option<&Value>) -> bool {
    weather_payload
        .and_then(|p| p.get("data"))
        .is_some()
}

#[derive(Debug, Clone)]
pub struct WeatherLocationMeta {
    pub latitude: f64,
    pub longitude: f64,
    pub elevation: Option<f64>,
    pub timezone: String,
}

pub fn weather_location_meta_from_source(
    source: &FieldCultivationClimateSourceSnapshot,
) -> WeatherLocationMeta {
    WeatherLocationMeta {
        latitude: source.farm_latitude,
        longitude: source.farm_longitude,
        elevation: None,
        timezone: source
            .weather_location_timezone
            .clone()
            .unwrap_or_else(|| "Asia/Tokyo".into()),
    }
}

#[cfg(test)]
mod mappers_field_cultivation_climate_weather_payload_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/mappers_field_cultivation_climate_weather_payload_mapper_test.rs"));
}
