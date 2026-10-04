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
            plan_metadata: None,
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
            plan_metadata: None,
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
    fn build_output_aligns_weather_data_span_with_truncated_gdd_data() {
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
            plan_metadata: None,
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
        let weather_records: Vec<Value> = (1..=5)
            .map(|day| {
                json!({
                    "date": format!("2026-03-{day:02}"),
                    "temperature_max": 30.0,
                    "temperature_min": 20.0,
                    "temperature_mean": 25.0
                })
            })
            .collect();
        let progress_result = json!({
            "progress_records": [
                { "date": "2026-03-01", "cumulative_gdd": 40.0, "stage_name": "S1" },
                { "date": "2026-03-02", "cumulative_gdd": 80.0, "stage_name": "S1" },
                { "date": "2026-03-03", "cumulative_gdd": 110.0, "stage_name": "S1" },
                { "date": "2026-03-04", "cumulative_gdd": 130.0, "stage_name": "S1" },
                { "date": "2026-03-05", "cumulative_gdd": 150.0, "stage_name": "S1" }
            ]
        });
        let dto = build_output(&context, &weather_records, &progress_result);
        assert_eq!(dto.gdd_data.len(), dto.weather_data.len());
        assert_eq!(dto.gdd_data[0]["date"], dto.weather_data[0]["date"]);
        assert_eq!(
            dto.gdd_data.last().unwrap()["date"],
            dto.weather_data.last().unwrap()["date"]
        );
    }

    #[test]
    fn build_output_uses_manual_gdd_when_progress_records_are_empty() {
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
            plan_metadata: None,
            crop_id: 2,
            base_temperature: 10.0,
            optimal_temperature_range: Some(json!({ "min": 15, "max": 25 })),
            stages: vec![],
        };
        let weather_records = vec![
            json!({
                "date": "2026-03-01",
                "temperature_max": 20.0,
                "temperature_min": 10.0,
                "temperature_mean": 15.0
            }),
            json!({
                "date": "2026-03-02",
                "temperature_max": 14.0,
                "temperature_min": 10.0,
                "temperature_mean": 12.0
            }),
        ];
        let progress_result = json!({ "progress_records": [] });
        let dto = build_output(&context, &weather_records, &progress_result);
        assert_eq!(dto.debug_info["using_agrr_progress"], false);
        assert_eq!(dto.gdd_data.len(), 2);
        assert_eq!(dto.gdd_data[0]["gdd"], 5.0);
        assert_eq!(dto.gdd_data[0]["cumulative_gdd"], 5.0);
        assert_eq!(dto.gdd_data[1]["gdd"], 2.0);
        assert_eq!(dto.gdd_data[1]["cumulative_gdd"], 7.0);
        assert!(dto.gdd_data[0]["current_stage"].is_null());
    }

    #[test]
    fn build_output_manual_gdd_derives_mean_from_max_and_min_when_mean_is_absent() {
        let context = FieldCultivationClimateContextSnapshot {
            field_cultivation_id: 1,
            field_name: "A".into(),
            crop_name: "Tomato".into(),
            start_date: date!(2026 - 03 - 01),
            completion_date: date!(2026 - 03 - 01),
            farm_id: 10,
            farm_name: "Farm".into(),
            farm_latitude: 35.0,
            farm_longitude: 139.0,
            plan_id: 5,
            plan_type_public: false,
            plan_predicted_weather_present: true,
            prediction_target_end_date: None,
            calculated_planning_end_date: None,
            plan_metadata: None,
            crop_id: 2,
            base_temperature: 10.0,
            optimal_temperature_range: None,
            stages: vec![],
        };
        let weather_records = vec![json!({
            "date": "2026-03-01",
            "temperature_max": 25.0,
            "temperature_min": 15.0
        })];
        let progress_result = json!({ "progress_records": [] });
        let dto = build_output(&context, &weather_records, &progress_result);
        assert_eq!(dto.gdd_data.len(), 1);
        assert_eq!(dto.gdd_data[0]["gdd"], 10.0);
        assert_eq!(dto.gdd_data[0]["temperature"], 20.0);
    }

    #[test]
    fn build_output_subtracts_baseline_cumulative_gdd_from_day_before_start_date() {
        let context = FieldCultivationClimateContextSnapshot {
            field_cultivation_id: 1,
            field_name: "A".into(),
            crop_name: "Tomato".into(),
            start_date: date!(2026 - 03 - 02),
            completion_date: date!(2026 - 03 - 03),
            farm_id: 10,
            farm_name: "Farm".into(),
            farm_latitude: 35.0,
            farm_longitude: 139.0,
            plan_id: 5,
            plan_type_public: false,
            plan_predicted_weather_present: true,
            prediction_target_end_date: None,
            calculated_planning_end_date: None,
            plan_metadata: None,
            crop_id: 2,
            base_temperature: 10.0,
            optimal_temperature_range: None,
            stages: vec![],
        };
        let progress_result = json!({
            "progress_records": [
                { "date": "2026-03-01", "cumulative_gdd": 50.0, "stage_name": "S1" },
                { "date": "2026-03-02", "cumulative_gdd": 60.0, "stage_name": "S1" },
                { "date": "2026-03-03", "cumulative_gdd": 75.0, "stage_name": "S1" }
            ]
        });
        let dto = build_output(&context, &[], &progress_result);
        assert_eq!(dto.debug_info["using_agrr_progress"], true);
        assert_eq!(dto.gdd_data.len(), 2);
        assert_eq!(dto.gdd_data[0]["date"], "2026-03-02");
        assert_eq!(dto.gdd_data[0]["gdd"], 10.0);
        assert_eq!(dto.gdd_data[0]["cumulative_gdd"], 10.0);
        assert_eq!(dto.gdd_data[1]["gdd"], 15.0);
        assert_eq!(dto.gdd_data[1]["cumulative_gdd"], 25.0);
    }

    #[test]
    fn build_output_leaves_gdd_empty_when_progress_dates_are_outside_cultivation_period() {
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
            plan_metadata: None,
            crop_id: 2,
            base_temperature: 10.0,
            optimal_temperature_range: None,
            stages: vec![],
        };
        let progress_result = json!({
            "progress_records": [
                { "date": "2026-03-10", "cumulative_gdd": 40.0, "stage_name": "S1" }
            ]
        });
        let dto = build_output(&context, &[], &progress_result);
        assert_eq!(dto.debug_info["using_agrr_progress"], true);
        assert!(dto.gdd_data.is_empty());
    }

    #[test]
    fn build_output_treats_null_cumulative_gdd_as_zero_in_agrr_progress_path() {
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
            plan_metadata: None,
            crop_id: 2,
            base_temperature: 10.0,
            optimal_temperature_range: None,
            stages: vec![],
        };
        let progress_result = json!({
            "progress_records": [
                { "date": "2026-03-01", "cumulative_gdd": null, "stage_name": "S1" },
                { "date": "2026-03-02", "cumulative_gdd": 12.0, "stage_name": "S1" }
            ]
        });
        let dto = build_output(&context, &[], &progress_result);
        assert_eq!(dto.debug_info["using_agrr_progress"], true);
        assert_eq!(dto.gdd_data.len(), 2);
        assert_eq!(dto.gdd_data[0]["gdd"], 0.0);
        assert_eq!(dto.gdd_data[0]["cumulative_gdd"], 0.0);
        assert_eq!(dto.gdd_data[1]["gdd"], 12.0);
        assert_eq!(dto.gdd_data[1]["cumulative_gdd"], 12.0);
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
