// Tests for `mappers/climate_crop_agrr_requirement_mapper.rs` (Ruby `CropAgrrRequirementMapper` parity).

use serde_json::json;

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
