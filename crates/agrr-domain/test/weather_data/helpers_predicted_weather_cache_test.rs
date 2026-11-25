// Tests for `helpers/predicted_weather_cache.rs` (cache payload normalization).

    use crate::weather_data::dtos::{PredictedWeatherMetadata, PredictedWeatherScope};
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

    #[test]
    fn build_metadata_from_payload_returns_none_without_prediction_dates() {
        let payload = json!({
            "data": [{ "time": "2026-06-15", "temperature_2m_mean": 20.0 }]
        });
        assert!(
            build_metadata_from_payload(
                PredictedWeatherScope::Plan,
                9,
                &payload,
                date!(2026-06-15),
                "generated".into()
            )
            .is_none()
        );
    }

    #[test]
    fn build_metadata_from_payload_returns_none_for_empty_data_array() {
        let payload = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2026-12-31",
            "data": []
        });
        assert!(
            build_metadata_from_payload(
                PredictedWeatherScope::Location,
                1,
                &payload,
                date!(2026-06-15),
                "generated".into()
            )
            .is_none()
        );
    }

    #[test]
    fn build_metadata_from_payload_allows_short_series_but_metadata_fails_covers_check() {
        let payload = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2026-12-31",
            "data": [{ "time": "2026-06-01", "temperature_2m_mean": 18.0 }]
        });
        let target = date!(2026-06-15);
        let meta = build_metadata_from_payload(
            PredictedWeatherScope::Plan,
            2,
            &payload,
            target,
            "generated".into(),
        )
        .expect("metadata row is still derived from payload headers");

        assert_eq!(meta.data_end_date, date!(2026-06-01));
        assert!(!metadata_covers_target(&meta, target));
    }

    #[test]
    fn build_metadata_from_payload_records_data_end_when_payload_covers_target() {
        let payload = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2026-12-31",
            "data": [
                { "time": "2026-06-01", "temperature_2m_mean": 18.0 },
                { "time": "2026-06-15", "temperature_2m_mean": 22.0 }
            ]
        });
        let meta = build_metadata_from_payload(
            PredictedWeatherScope::Plan,
            3,
            &payload,
            date!(2026-06-15),
            "2026-06-01T00:00:00Z".into(),
        )
        .expect("metadata");

        assert_eq!(meta.scope, PredictedWeatherScope::Plan);
        assert_eq!(meta.scope_id, 3);
        assert_eq!(meta.prediction_end_date, date!(2026-12-31));
        assert_eq!(meta.target_end_date, date!(2026-06-15));
        assert_eq!(meta.data_end_date, date!(2026-06-15));
        assert_eq!(meta.generated_at, "2026-06-01T00:00:00Z");
    }

    #[test]
    fn metadata_covers_target_requires_prediction_span_and_data_through_target() {
        let covers = PredictedWeatherMetadata {
            scope: PredictedWeatherScope::Location,
            scope_id: 1,
            prediction_start_date: date!(2026-01-01),
            prediction_end_date: date!(2026-12-31),
            target_end_date: date!(2026-06-15),
            data_end_date: date!(2026-06-15),
            generated_at: "gen".into(),
        };
        let short_span = PredictedWeatherMetadata {
            prediction_end_date: date!(2026-06-01),
            ..covers.clone()
        };
        let short_series = PredictedWeatherMetadata {
            data_end_date: date!(2026-06-01),
            ..covers.clone()
        };

        assert!(metadata_covers_target(&covers, date!(2026-06-15)));
        assert!(!metadata_covers_target(&short_span, date!(2026-12-31)));
        assert!(!metadata_covers_target(&short_series, date!(2026-06-15)));
    }

    #[test]
    fn cached_prediction_from_payload_returns_none_for_empty_data() {
        let payload = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2026-12-31",
            "data": []
        });
        assert!(cached_prediction_from_payload(&payload, date!(2026-06-15)).is_none());
    }

    #[test]
    fn cached_future_data_returns_none_when_rows_only_after_target() {
        let payload = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2026-12-31",
            "data": [{ "time": "2026-07-01", "temperature_2m_mean": 28.0 }]
        });

        assert!(cached_future_data(&payload, date!(2026-06-15)).is_none());
    }

    #[test]
    fn cached_future_data_returns_none_when_prediction_dates_are_unparseable() {
        let payload = json!({
            "prediction_start_date": "not-a-date",
            "prediction_end_date": "2026-12-31",
            "data": [{ "time": "2026-06-15", "temperature_2m_mean": 20.0 }]
        });

        assert!(cached_future_data(&payload, date!(2026-06-15)).is_none());
    }

    #[test]
    fn cached_prediction_from_payload_returns_none_when_prediction_end_before_target() {
        let payload = json!({
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2026-06-01",
            "data": [{ "time": "2026-06-15", "temperature_2m_mean": 20.0 }]
        });

        assert!(cached_prediction_from_payload(&payload, date!(2026-12-31)).is_none());
    }

    #[test]
    fn metadata_covers_target_accepts_data_end_on_target_day() {
        let on_target = PredictedWeatherMetadata {
            scope: PredictedWeatherScope::Plan,
            scope_id: 4,
            prediction_start_date: date!(2026-01-01),
            prediction_end_date: date!(2026-12-31),
            target_end_date: date!(2026-06-15),
            data_end_date: date!(2026-06-15),
            generated_at: "gen".into(),
        };

        assert!(metadata_covers_target(&on_target, date!(2026-06-15)));
        assert!(!metadata_covers_target(&on_target, date!(2026-06-16)));
    }
