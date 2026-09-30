// Tests for `mappers/climate_crop_agrr_requirement_mapper.rs` (Ruby `CropAgrrRequirementMapper` parity).

use serde_json::json;


    struct EmptyScopeGateway;
    impl crate::shared::gateways::UserOrganizationScopeGateway for EmptyScopeGateway {
        fn organization_ids_for_user(
            &self,
            _: i64,
        ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }
    }
#[test]
fn builds_rails_crop_requirement_shape() {
    let entity = ClimateCropEntity {
        id: 42,
        name: "キャベツ".into(),
        variety: Some("春".into()),
        area_per_unit: Some(0.25),
        revenue_per_area: Some(5000.0),
        groups: json!(["leafy"]),
        is_reference: true,
        user_id: None,
        crop_stages: vec![ClimateCropStage {
            name: "育苗".into(),
            order: 1,
            temperature_requirement: Some(ClimateTemperatureRequirement {
                base_temperature: 4.0,
                optimal_min: Some(15.0),
                optimal_max: Some(20.0),
                low_stress_threshold: Some(5.0),
                high_stress_threshold: Some(30.0),
                frost_threshold: Some(0.0),
                max_temperature: Some(50.0),
            }),
            thermal_requirement: Some(ClimateThermalRequirement {
                required_gdd: 300.0,
            }),
        }],
    };

    let req = from_climate_crop_entity(&entity);
    assert_eq!(req["crop"]["crop_id"], "42");
    assert_eq!(req["crop"]["name"], "キャベツ");
    assert!(req.get("stage_requirements").is_some());
    assert!(req["crop"].get("stages").is_none());

    let stage = &req["stage_requirements"][0];
    assert_eq!(stage["stage"]["name"], "育苗");
    assert_eq!(stage["thermal"]["required_gdd"], 300.0);
    assert_eq!(stage["temperature"]["base_temperature"], 4.0);
}

#[test]
fn omits_stages_missing_temperature_or_thermal_requirements() {
    let entity = ClimateCropEntity {
        id: 1,
        name: "X".into(),
        variety: None,
        area_per_unit: None,
        revenue_per_area: None,
        groups: json!([]),
        is_reference: false,
        user_id: None,
        crop_stages: vec![
            ClimateCropStage {
                name: "no_temp".into(),
                order: 1,
                temperature_requirement: None,
                thermal_requirement: Some(ClimateThermalRequirement {
                    required_gdd: 10.0,
                }),
            },
            ClimateCropStage {
                name: "ok".into(),
                order: 2,
                temperature_requirement: Some(ClimateTemperatureRequirement {
                    base_temperature: 5.0,
                    optimal_min: None,
                    optimal_max: None,
                    low_stress_threshold: None,
                    high_stress_threshold: None,
                    frost_threshold: None,
                    max_temperature: None,
                }),
                thermal_requirement: Some(ClimateThermalRequirement {
                    required_gdd: 20.0,
                }),
            },
        ],
    };
    let req = from_climate_crop_entity(&entity);
    assert_eq!(req["stage_requirements"].as_array().unwrap().len(), 1);
    assert_eq!(req["stage_requirements"][0]["stage"]["name"], "ok");
}

#[test]
fn applies_default_crop_fields_when_optional_attributes_are_absent() {
    let entity = ClimateCropEntity {
        id: 7,
        name: "Bare".into(),
        variety: None,
        area_per_unit: None,
        revenue_per_area: None,
        groups: json!([]),
        is_reference: false,
        user_id: None,
        crop_stages: vec![ClimateCropStage {
            name: "S".into(),
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
            thermal_requirement: Some(ClimateThermalRequirement {
                required_gdd: 1.0,
            }),
        }],
    };
    let req = from_climate_crop_entity(&entity);
    assert_eq!(req["crop"]["variety"], "general");
    assert_eq!(req["crop"]["area_per_unit"], 0.25);
    assert_eq!(req["crop"]["revenue_per_area"], 5000.0);
    assert_eq!(req["crop"]["max_revenue"], 500_000.0);
    assert_eq!(req["stage_requirements"][0]["temperature"]["max_temperature"], 50.0);
}
