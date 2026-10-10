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

    // Locks docs/spec-defects/06 item C: empty cached payload still yields 200 when observed fills `data`.
    #[test]
    fn merge_cached_with_observed_uses_observed_when_cached_has_no_data() {
        let cached = json!({});
        let observed = json!({
            "data": [{ "time": "2024-06-01", "temperature_2m_mean": 18.0 }]
        });
        let merged = merge_cached_with_observed(&cached, &observed);
        let data = merged.get("data").unwrap().as_array().unwrap();
        assert_eq!(data.len(), 1);
        assert_eq!(data[0]["temperature_2m_mean"], 18.0);
    }

    // Locks docs/spec-defects/06 H4: missing timezone becomes Asia/Tokyo until fail-closed fix.
    #[test]
    fn weather_location_meta_from_source_defaults_timezone_when_missing() {
        use crate::field_cultivation::dtos::field_cultivation_climate_source_snapshot::FieldCultivationClimateSourceSnapshot;

        let source = FieldCultivationClimateSourceSnapshot {
            field_cultivation_id: 1,
            field_name: "Field".into(),
            crop_name: "Crop".into(),
            start_date: None,
            completion_date: None,
            farm_id: 1,
            farm_name: "Farm".into(),
            farm_latitude: 35.0,
            farm_longitude: 139.0,
            weather_location_id: Some(1),
            weather_location_timezone: None,
            plan_id: 1,
            plan_type_public: true,
            prediction_target_end_date: None,
            calculated_planning_end_date: None,
            plan_metadata: None,
            plan_crop_crop_id: None,
        };
        let meta = weather_location_meta_from_source(&source);
        assert_eq!(meta.timezone, "Asia/Tokyo");
        assert_eq!(meta.latitude, 35.0);
    }
