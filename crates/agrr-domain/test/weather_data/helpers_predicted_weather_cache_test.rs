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

    #[test]
    fn cached_future_data_returns_none_when_prediction_end_before_target() {
        let payload = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2026-06-01",
            "data": [{ "time": "2026-06-15", "temperature_2m_mean": 20.0 }]
        });

        assert!(cached_future_data(&payload, date!(2026-12-31)).is_none());
    }

    #[test]
    fn cached_future_data_excludes_rows_outside_prediction_window() {
        let payload = json!({
            "prediction_start_date": "2026-04-01",
            "prediction_end_date": "2026-12-31",
            "data": [
                { "time": "2026-03-15", "temperature_2m_mean": 1.0 },
                { "time": "2026-06-15", "temperature_2m_mean": 22.5 },
                { "time": "2026-07-01", "temperature_2m_mean": 99.0 }
            ]
        });

        let future = cached_future_data(&payload, date!(2026-06-15)).expect("future slice");
        let rows = future
            .get("data")
            .and_then(|v| v.as_array())
            .expect("data rows");

        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].get("time").and_then(|v| v.as_str()), Some("2026-06-15"));
        assert_eq!(
            rows[0].get("temperature_2m_mean").and_then(|v| v.as_f64()),
            Some(22.5)
        );
    }

    #[test]
    fn cached_future_data_returns_none_when_series_ends_before_target() {
        let payload = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2026-12-31",
            "data": [{ "time": "2026-06-01", "temperature_2m_mean": 18.0 }]
        });

        assert!(cached_future_data(&payload, date!(2026-06-15)).is_none());
    }

    #[test]
    fn payload_covers_target_requires_prediction_span_and_data_through_target() {
        let covered = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2026-12-31",
            "data": [{ "time": "2026-06-15", "temperature_2m_mean": 20.0 }]
        });
        let short_span = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2026-06-01",
            "data": [{ "time": "2026-06-15", "temperature_2m_mean": 20.0 }]
        });
        let short_series = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2026-12-31",
            "data": [{ "time": "2026-06-01", "temperature_2m_mean": 20.0 }]
        });

        assert!(payload_covers_target(&covered, date!(2026-06-15)));
        assert!(!payload_covers_target(&short_span, date!(2026-12-31)));
        assert!(!payload_covers_target(&short_series, date!(2026-06-15)));
    }

    #[test]
    fn cached_prediction_from_payload_returns_days_through_extended_target() {
        let payload = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2026-06-30",
            "data": [
                { "time": "2026-06-01", "temperature_2m_mean": 18.0 },
                { "time": "2026-06-15", "temperature_2m_mean": 22.0 }
            ]
        });

        let cached =
            cached_prediction_from_payload(&payload, date!(2026-06-15)).expect("cache hit");

        assert_eq!(cached.prediction_start_date, "2026-01-01");
        assert_eq!(cached.prediction_days, 181);
        assert_eq!(
            cached
                .data
                .get("prediction_start_date")
                .and_then(|v| v.as_str()),
            Some("2026-01-01")
        );
    }
