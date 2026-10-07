// Tests for `mappers/field_cultivation_climate_context_snapshot_mapper.rs` (Ruby parity under test/domain/field_cultivation/).

    use time::macros::date;

    #[test]
    fn maps_crop_stages_into_context() {
        let source = FieldCultivationClimateSourceSnapshot {
            field_cultivation_id: 1,
            field_name: "A".into(),
            crop_name: "Tomato".into(),
            start_date: Some(date!(2026 - 03 - 01)),
            completion_date: Some(date!(2026 - 03 - 10)),
            farm_id: 10,
            farm_name: "Farm".into(),
            farm_latitude: 35.0,
            farm_longitude: 139.0,
            weather_location_id: Some(1),
            weather_location_timezone: None,
            plan_id: 5,
            plan_type_public: false,
            prediction_target_end_date: None,
            calculated_planning_end_date: None,
            plan_metadata: None,
            plan_crop_crop_id: Some(2),
        };
        let crop = ClimateCropEntity {
            id: 2,
            name: "Tomato".into(),
            variety: None,
            area_per_unit: None,
            revenue_per_area: None,
            groups: serde_json::json!([]),
            is_reference: false,
            user_id: Some(1),
            crop_stages: vec![ClimateCropStage {
                name: "S1".into(),
                order: 1,
                temperature_requirement: Some(ClimateTemperatureRequirement {
                    base_temperature: 10.0,
                    optimal_min: Some(15.0),
                    optimal_max: Some(25.0),
                    low_stress_threshold: None,
                    high_stress_threshold: None,
                    frost_threshold: None,
                    max_temperature: None,
                }),
                thermal_requirement: Some(
                    crate::field_cultivation::dtos::ClimateThermalRequirement {
                        required_gdd: 100.0,
                    },
                ),
            }],
        };
        let ctx = to_context_snapshot(&source, &crop).expect("context snapshot");
        assert_eq!(ctx.crop_id, 2);
        assert_eq!(ctx.stages.len(), 1);
    }

    fn minimal_source() -> FieldCultivationClimateSourceSnapshot {
        FieldCultivationClimateSourceSnapshot {
            field_cultivation_id: 1,
            field_name: "A".into(),
            crop_name: "Tomato".into(),
            start_date: Some(date!(2026 - 03 - 01)),
            completion_date: Some(date!(2026 - 03 - 10)),
            farm_id: 10,
            farm_name: "Farm".into(),
            farm_latitude: 35.0,
            farm_longitude: 139.0,
            weather_location_id: Some(1),
            weather_location_timezone: None,
            plan_id: 5,
            plan_type_public: false,
            prediction_target_end_date: None,
            calculated_planning_end_date: None,
            plan_metadata: None,
            plan_crop_crop_id: Some(2),
        }
    }

    #[test]
    fn errors_when_lowest_order_stage_has_no_temperature() {
        let crop = ClimateCropEntity {
            id: 2,
            name: "Tomato".into(),
            variety: None,
            area_per_unit: None,
            revenue_per_area: None,
            groups: serde_json::json!([]),
            is_reference: false,
            user_id: Some(1),
            crop_stages: vec![ClimateCropStage {
                name: "S1".into(),
                order: 1,
                temperature_requirement: None,
                thermal_requirement: Some(
                    crate::field_cultivation::dtos::ClimateThermalRequirement {
                        required_gdd: 100.0,
                    },
                ),
            }],
        };
        let err = to_context_snapshot(&minimal_source(), &crop).expect_err("incomplete crop");
        assert_eq!(
            err.0.reason,
            crate::field_cultivation::dtos::FieldCultivationClimateFailureReason::CropRequirementIncomplete
        );
    }

    #[test]
    fn accumulates_cumulative_gdd_required_across_ordered_stages() {
        let crop = ClimateCropEntity {
            id: 2,
            name: "Tomato".into(),
            variety: None,
            area_per_unit: None,
            revenue_per_area: None,
            groups: serde_json::json!([]),
            is_reference: false,
            user_id: Some(1),
            crop_stages: vec![
                ClimateCropStage {
                    name: "S2".into(),
                    order: 2,
                    temperature_requirement: Some(ClimateTemperatureRequirement {
                        base_temperature: 10.0,
                        optimal_min: None,
                        optimal_max: None,
                        low_stress_threshold: None,
                        high_stress_threshold: None,
                        frost_threshold: None,
                        max_temperature: None,
                    }),
                    thermal_requirement: Some(
                        crate::field_cultivation::dtos::ClimateThermalRequirement {
                            required_gdd: 50.0,
                        },
                    ),
                },
                ClimateCropStage {
                    name: "S1".into(),
                    order: 1,
                    temperature_requirement: Some(ClimateTemperatureRequirement {
                        base_temperature: 10.0,
                        optimal_min: None,
                        optimal_max: None,
                        low_stress_threshold: None,
                        high_stress_threshold: None,
                        frost_threshold: None,
                        max_temperature: None,
                    }),
                    thermal_requirement: Some(
                        crate::field_cultivation::dtos::ClimateThermalRequirement {
                            required_gdd: 30.0,
                        },
                    ),
                },
            ],
        };
        let ctx = to_context_snapshot(&minimal_source(), &crop).expect("context snapshot");
        assert_eq!(ctx.stages.len(), 2);
        assert_eq!(ctx.stages[0]["order"], 1);
        assert_eq!(ctx.stages[0]["cumulative_gdd_required"], 30.0);
        assert_eq!(ctx.stages[1]["order"], 2);
        assert_eq!(ctx.stages[1]["cumulative_gdd_required"], 80.0);
    }
