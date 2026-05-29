// Tests for `normalizers/entry_schedule_weather_payload_normalizer.rs` (Ruby parity under test/domain/cultivation_plan/).

    use serde_json::json;

    fn sample_rows() -> Vec<Value> {
        (1..=3)
            .map(|d| {
                json!({
                    "time": format!("2026-05-{d:02}"),
                    "temperature_2m_min": 8.0,
                    "temperature_2m_max": 22.0,
                    "temperature_2m_mean": 15.0
                })
            })
            .collect()
    }

    // Ruby: test "flattens nested data.data shape"
    #[test]
    fn flattens_nested_data_data_shape() {
        let rows = sample_rows();
        let nested = json!({
            "data": {
                "data": rows,
                "latitude": 35.5,
                "longitude": 139.7
            },
            "prediction_end_date": "2026-12-31"
        });

        let out = call(Some(&nested));
        let obj = out.as_object().expect("object");
        assert!(obj.get("data").expect("data").is_array());
        assert_eq!(obj.get("data").unwrap().as_array().unwrap().len(), 3);
        let lat = obj.get("latitude").unwrap().as_f64().unwrap();
        let lon = obj.get("longitude").unwrap().as_f64().unwrap();
        assert!((lat - 35.5).abs() < 0.001);
        assert!((lon - 139.7).abs() < 0.001);
    }

    // Ruby: test "leaves flat payload unchanged"
    #[test]
    fn leaves_flat_payload_unchanged() {
        let rows = sample_rows();
        let flat = json!({
            "latitude": 35.0,
            "longitude": 139.0,
            "data": rows
        });
        let out = call(Some(&flat));
        let obj = out.as_object().expect("object");
        assert_eq!(obj.get("data").unwrap().as_array().unwrap().len(), 3);
        let lat = obj.get("latitude").unwrap().as_f64().unwrap();
        assert!((lat - 35.0).abs() < 0.001);
    }
