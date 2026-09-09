// Tests for `normalizers/entry_schedule_weather_location_enricher.rs`

    use crate::cultivation_plan::normalizers::entry_schedule_weather_location_enricher;
    use crate::cultivation_plan::normalizers::entry_schedule_weather_payload_normalizer;
    use crate::shared::hash::present;
    use crate::weather_data::dtos::WeatherLocation;
    use serde_json::json;

    #[test]
    fn enrich_fills_missing_coordinates_from_location() {
        let mut payload = json!({
            "data": [{ "time": "2026-09-09", "temperature_2m_mean": 20.0 }]
        });
        let location =
            WeatherLocation::new(28, 34.7303, 136.5086, Some(10.0), Some("Asia/Tokyo".into()));
        entry_schedule_weather_location_enricher::enrich_from_location(&mut payload, &location);
        assert_eq!(payload.get("latitude").and_then(|v| v.as_f64()), Some(34.7303));
        assert_eq!(payload.get("longitude").and_then(|v| v.as_f64()), Some(136.5086));
        assert_eq!(payload.get("elevation").and_then(|v| v.as_f64()), Some(10.0));
        assert_eq!(
            payload.get("timezone").and_then(|v| v.as_str()),
            Some("Asia/Tokyo")
        );
    }

    #[test]
    fn enrich_preserves_existing_coordinates() {
        let mut payload = json!({
            "latitude": 1.0,
            "longitude": 2.0,
            "data": [{ "time": "2026-09-09", "temperature_2m_mean": 20.0 }]
        });
        let location = WeatherLocation::new(28, 34.7303, 136.5086, None, None);
        entry_schedule_weather_location_enricher::enrich_from_location(&mut payload, &location);
        assert_eq!(payload.get("latitude").and_then(|v| v.as_f64()), Some(1.0));
        assert_eq!(payload.get("longitude").and_then(|v| v.as_f64()), Some(2.0));
    }

    #[test]
    fn normalizer_and_enrich_prepare_cached_future_shape() {
        let rows = vec![
            json!({ "time": "2026-09-09", "temperature_2m_mean": 20.0 }),
            json!({ "time": "2026-09-10", "temperature_2m_mean": 21.0 }),
        ];
        let cached_future_shape = json!({ "data": rows });
        let location = WeatherLocation::new(28, 34.7303, 136.5086, None, None);
        let mut payload =
            entry_schedule_weather_payload_normalizer::call(Some(&cached_future_shape));
        entry_schedule_weather_location_enricher::enrich_from_location(&mut payload, &location);
        assert!(payload.get("latitude").map(present).unwrap_or(false));
        assert!(payload.get("longitude").map(present).unwrap_or(false));
        assert_eq!(payload["data"].as_array().unwrap().len(), 2);
    }
