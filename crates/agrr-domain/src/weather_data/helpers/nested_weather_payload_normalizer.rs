//! Ruby: `PlanAllocationAdjustInteractor#normalize_nested_weather_data` /
//! `CompositionRoot` `weather_for_candidates` unwrap.

use serde_json::Value;

/// Unwraps `{ "data": { "data": [..], "latitude": .. } }` → inner hash (Rails parity).
pub fn normalize_nested_weather_data(weather_data: Value) -> Value {
    let inner_is_array = weather_data
        .get("data")
        .and_then(|d| d.get("data"))
        .and_then(|d| d.as_array())
        .is_some();
    let data_is_object = weather_data
        .get("data")
        .and_then(|v| v.as_object())
        .is_some();

    if data_is_object && inner_is_array {
        weather_data
            .get("data")
            .cloned()
            .unwrap_or(weather_data)
    } else {
        weather_data
    }
}

#[cfg(test)]
mod nested_weather_payload_normalizer_test {
    use super::*;
    use serde_json::json;

    #[test]
    fn unwraps_double_nested_data_preserving_latitude() {
        let nested = json!({
            "latitude": 35.0,
            "longitude": 139.0,
            "data": [{ "time": "2026-01-01", "temperature_2m_max": 10.0 }]
        });
        let input = json!({ "data": nested });
        let out = normalize_nested_weather_data(input);
        assert_eq!(out.get("latitude").and_then(|v| v.as_f64()), Some(35.0));
        assert!(out.get("data").and_then(|v| v.as_array()).is_some());
    }

    #[test]
    fn leaves_flat_agrr_payload_unchanged() {
        let flat = json!({
            "latitude": 35.0,
            "data": [{ "time": "2026-01-01" }]
        });
        let out = normalize_nested_weather_data(flat.clone());
        assert_eq!(out, flat);
    }
}
