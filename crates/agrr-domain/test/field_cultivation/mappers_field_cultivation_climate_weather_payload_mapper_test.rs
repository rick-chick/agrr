// Tests for `mappers/field_cultivation_climate_weather_payload_mapper.rs` (Ruby parity under test/domain/field_cultivation/).

use serde_json::json;

    use time::macros::date;

    #[test]
    fn coerce_optional_date_normalizes_values() {
        let d = date!(2024 - 06 - 01);
        assert_eq!(coerce_optional_date("2024-06-01"), Some(d));
        assert_eq!(coerce_optional_date("not-a-date"), None);
    }

    #[test]
    fn merge_cached_with_observed_overwrites_by_date_key() {
        let cached = json!({
            "data": [{ "time": "2024-06-01", "temperature_2m_mean": 10.0 }]
        });
        let observed = json!({
            "data": [
                { "time": "2024-06-01", "temperature_2m_mean": 20.0 },
                { "time": "2024-06-02", "temperature_2m_mean": 15.0 }
            ]
        });
        let merged = merge_cached_with_observed(&cached, &observed);
        let data = merged.get("data").unwrap().as_array().unwrap();
        assert_eq!(data.len(), 2);
        let june1 = data.iter().find(|d| d["time"] == "2024-06-01").unwrap();
        assert_eq!(june1["temperature_2m_mean"], 20.0);
    }

    #[test]
    fn merge_cached_with_observed_returns_cached_when_observed_empty() {
        let cached = json!({ "data": [{ "time": "2024-06-01" }] });
        let merged = merge_cached_with_observed(&cached, &json!({ "data": [] }));
        assert_eq!(merged, cached);
    }
