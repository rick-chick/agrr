// Tests for `helpers/finalize_weather_payload_for_agrr.rs`

use serde_json::json;

#[test]
fn finalize_weather_payload_rejects_empty_data_rows() {
    let payload = json!({ "data": [] });
    let err = finalize_weather_payload_for_agrr(payload).unwrap_err();
    assert_eq!(err, FinalizeWeatherPayloadError::EmptyDataRows);
    assert_eq!(err.to_string(), "weather payload has no data rows");
}

#[test]
fn finalize_weather_payload_accepts_non_empty_data() {
    let payload = json!({
        "data": [{ "time": "2026-05-01", "temperature_2m_mean": 15.0 }]
    });
    let normalized = finalize_weather_payload_for_agrr(payload).unwrap();
    assert_eq!(normalized["data"].as_array().unwrap().len(), 1);
}

#[test]
fn finalize_weather_payload_unwraps_nested_data() {
    let nested = json!({
        "latitude": 35.0,
        "longitude": 139.0,
        "data": [{ "time": "2026-01-01", "temperature_2m_max": 10.0 }]
    });
    let payload = json!({ "data": nested });
    let normalized = finalize_weather_payload_for_agrr(payload).unwrap();
    assert_eq!(normalized.get("latitude").and_then(|v| v.as_f64()), Some(35.0));
    assert_eq!(normalized["data"].as_array().unwrap().len(), 1);
}
