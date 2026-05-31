// Tests for `mappers/field_cultivation_climate_data_mapper.rs` (Ruby parity under test/domain/field_cultivation/).

    use serde_json::json;
    use time::macros::date;

    #[test]
    fn build_output_assembles_climate_dto() {
        let context = FieldCultivationClimateContextSnapshot {
            field_cultivation_id: 1,
            field_name: "A".into(),
            crop_name: "Tomato".into(),
            start_date: date!(2026 - 03 - 01),
            completion_date: date!(2026 - 03 - 02),
            farm_id: 10,
            farm_name: "Farm".into(),
            farm_latitude: 35.0,
            farm_longitude: 139.0,
            plan_id: 5,
            plan_type_public: false,
            plan_predicted_weather_present: true,
            prediction_target_end_date: None,
            calculated_planning_end_date: None,
            predicted_weather_data: Some(json!({})),
            crop_id: 2,
            base_temperature: 10.0,
            optimal_temperature_range: Some(json!({ "min": 15, "max": 25 })),
            stages: vec![],
        };
        let weather_records = vec![json!({
            "date": "2026-03-01",
            "temperature_max": 20.0,
            "temperature_min": 10.0,
            "temperature_mean": 15.0
        })];
        let progress_result = json!({
            "progress_records": [
                { "date": "2026-03-01", "cumulative_gdd": 5.0, "stage_name": "S1" }
            ]
        });
        let dto = build_output(&context, &weather_records, &progress_result);
        assert_eq!(dto.field_cultivation["id"], 1);
        assert_eq!(dto.farm["id"], 10);
        assert_eq!(dto.weather_data.len(), 1);
        assert_eq!(dto.gdd_data[0]["gdd"], 5.0);
        assert_eq!(dto.debug_info["using_agrr_progress"], true);
    }

    #[test]
    fn build_output_truncates_gdd_at_final_cumulative_requirement() {
        let context = FieldCultivationClimateContextSnapshot {
            field_cultivation_id: 1,
            field_name: "A".into(),
            crop_name: "Tomato".into(),
            start_date: date!(2026 - 03 - 01),
            completion_date: date!(2026 - 03 - 05),
            farm_id: 10,
            farm_name: "Farm".into(),
            farm_latitude: 35.0,
            farm_longitude: 139.0,
            plan_id: 5,
            plan_type_public: false,
            plan_predicted_weather_present: true,
            prediction_target_end_date: None,
            calculated_planning_end_date: None,
            predicted_weather_data: Some(json!({})),
            crop_id: 2,
            base_temperature: 10.0,
            optimal_temperature_range: Some(json!({ "min": 15, "max": 25 })),
            stages: vec![json!({
                "name": "Stage1",
                "order": 1,
                "gdd_required": 100.0,
                "cumulative_gdd_required": 100.0
            })],
        };
        let progress_result = json!({
            "progress_records": [
                { "date": "2026-03-01", "cumulative_gdd": 40.0, "stage_name": "S1" },
                { "date": "2026-03-02", "cumulative_gdd": 80.0, "stage_name": "S1" },
                { "date": "2026-03-03", "cumulative_gdd": 110.0, "stage_name": "S1" },
                { "date": "2026-03-04", "cumulative_gdd": 130.0, "stage_name": "S1" },
                { "date": "2026-03-05", "cumulative_gdd": 150.0, "stage_name": "S1" }
            ]
        });
        let dto = build_output(&context, &[], &progress_result);
        assert_eq!(dto.gdd_data.len(), 3);
        assert_eq!(dto.gdd_data[2]["date"], "2026-03-03");
        assert!((dto.gdd_data[2]["cumulative_gdd"].as_f64().unwrap() - 110.0).abs() < 0.01);
    }

    #[test]
    fn extract_weather_records_filters_by_period() {
        let payload = json!({
            "data": [
                { "time": "2026-01-01", "temperature_2m_max": 10, "temperature_2m_min": 0 },
                { "time": "2026-06-01", "temperature_2m_max": 20, "temperature_2m_min": 10 }
            ]
        });
        let records = extract_weather_records(
            Some(&payload),
            date!(2026 - 05 - 01),
            date!(2026 - 06 - 30),
        );
        assert_eq!(records.len(), 1);
        assert_eq!(records[0]["date"], "2026-06-01");
    }
