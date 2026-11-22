// Tests for `helpers/predicted_weather_cache.rs` (cache payload normalization).

    use serde_json::json;
    use time::macros::date;

    #[test]
    fn cached_future_data_fills_missing_precipitation_and_weather_code_with_zero() {
        // Locks fail-open defaults (docs/spec-defects/06 §2.4): missing optional metrics become 0.0 / 0.
        let payload = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2027-12-31",
            "data": [
                {
                    "time": "2026-06-15",
                    "temperature_2m_mean": 22.5
                }
            ]
        });
        let target = date!(2026-06-15);

        let future = cached_future_data(&payload, target).expect("filtered future data");
        let row = future
            .get("data")
            .and_then(|v| v.as_array())
            .and_then(|rows| rows.first())
            .expect("one row");

        assert_eq!(row.get("precipitation_sum").and_then(|v| v.as_f64()), Some(0.0));
        assert_eq!(row.get("sunshine_duration").and_then(|v| v.as_f64()), Some(0.0));
        assert_eq!(row.get("wind_speed_10m_max").and_then(|v| v.as_f64()), Some(0.0));
        assert_eq!(row.get("weather_code").and_then(|v| v.as_i64()), Some(0));
        assert_eq!(row.get("temperature_2m_mean").and_then(|v| v.as_f64()), Some(22.5));
    }

    #[test]
    fn cached_future_data_maps_legacy_open_meteo_temperature_aliases() {
        let payload = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2027-12-31",
            "data": [
                {
                    "date": "2026-06-15",
                    "temperature_max": 30.0,
                    "temperature_min": 12.0,
                    "temperature_mean": 21.0,
                    "precipitation": 4.5,
                    "wind_speed": 8.2
                }
            ]
        });
        let target = date!(2026-06-15);

        let future = cached_future_data(&payload, target).expect("filtered future data");
        let row = future
            .get("data")
            .and_then(|v| v.as_array())
            .and_then(|rows| rows.first())
            .expect("one row");

        assert_eq!(row.get("time").and_then(|v| v.as_str()), Some("2026-06-15"));
        assert_eq!(row.get("temperature_2m_max").and_then(|v| v.as_f64()), Some(30.0));
        assert_eq!(row.get("temperature_2m_min").and_then(|v| v.as_f64()), Some(12.0));
        assert_eq!(row.get("temperature_2m_mean").and_then(|v| v.as_f64()), Some(21.0));
        assert_eq!(row.get("precipitation_sum").and_then(|v| v.as_f64()), Some(4.5));
        assert_eq!(row.get("wind_speed_10m_max").and_then(|v| v.as_f64()), Some(8.2));
    }
