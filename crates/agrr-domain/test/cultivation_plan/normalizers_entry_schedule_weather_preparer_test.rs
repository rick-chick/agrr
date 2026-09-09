// Tests for `normalizers/entry_schedule_weather_preparer.rs`

    use crate::cultivation_plan::normalizers::entry_schedule_weather_preparer::{
        self, EntryScheduleWeatherPrepareError,
    };
    use crate::shared::hash::present;
    use crate::weather_data::dtos::WeatherLocation;
    use serde_json::json;

    #[test]
    fn prepare_enriches_gcs_cache_shape_with_location() {
        let payload = json!({
            "data": [
                { "time": "2026-09-09", "temperature_2m_mean": 20.0 },
                { "time": "2026-09-10", "temperature_2m_mean": 21.0 }
            ]
        });
        let location =
            WeatherLocation::new(28, 34.7303, 136.5086, Some(10.0), Some("Asia/Tokyo".into()));

        let prepared = entry_schedule_weather_preparer::prepare(payload, &location).unwrap();

        assert!(prepared.get("latitude").map(present).unwrap_or(false));
        assert!(prepared.get("longitude").map(present).unwrap_or(false));
        assert_eq!(prepared.get("latitude").and_then(|v| v.as_f64()), Some(34.7303));
        assert_eq!(prepared.get("longitude").and_then(|v| v.as_f64()), Some(136.5086));
        assert_eq!(prepared.get("elevation").and_then(|v| v.as_f64()), Some(10.0));
        assert_eq!(
            prepared.get("timezone").and_then(|v| v.as_str()),
            Some("Asia/Tokyo")
        );
        let data = prepared.get("data").and_then(|v| v.as_array()).unwrap();
        assert_eq!(data.len(), 2);
        assert!(data[0].get("time").is_some());
    }

    #[test]
    fn prepare_enriches_contract_gcs_cache_seed_shape_without_coordinates() {
        let payload = json!({
            "data": [
                { "time": "2026-09-09", "temperature_2m_mean": 15.0 },
                { "time": "2026-10-09", "temperature_2m_mean": 16.0 }
            ],
            "prediction_start_date": "2026-01-01",
            "prediction_end_date": "2027-12-31",
            "target_end_date": "2027-12-31"
        });
        let location =
            WeatherLocation::new(28, 35.6895, 139.6917, Some(40.0), Some("Asia/Tokyo".into()));

        let prepared = entry_schedule_weather_preparer::prepare(payload, &location).unwrap();

        assert_eq!(prepared.get("latitude").and_then(|v| v.as_f64()), Some(35.6895));
        assert_eq!(prepared.get("longitude").and_then(|v| v.as_f64()), Some(139.6917));
        assert_eq!(prepared["data"].as_array().unwrap().len(), 2);
    }

    #[test]
    fn prepare_rejects_empty_data_rows() {
        let payload = json!({ "data": [] });
        let location = WeatherLocation::new(28, 34.7303, 136.5086, None, None);

        let err = entry_schedule_weather_preparer::prepare(payload, &location).unwrap_err();

        assert_eq!(err, EntryScheduleWeatherPrepareError::EmptyDataRows);
        assert!(err.to_string().contains("no data rows"));
    }
