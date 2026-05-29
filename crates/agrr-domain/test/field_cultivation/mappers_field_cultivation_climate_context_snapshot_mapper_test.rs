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
            predicted_weather_data: None,
            plan_crop_crop_id: Some(2),
        };
        let crop = ClimateCropEntity {
            id: 2,
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
                }),
                thermal_requirement: Some(
                    crate::field_cultivation::dtos::ClimateThermalRequirement {
                        required_gdd: 100.0,
                    },
                ),
            }],
        };
        let ctx = to_context_snapshot(&source, &crop);
        assert_eq!(ctx.crop_id, 2);
        assert_eq!(ctx.stages.len(), 1);
    }
