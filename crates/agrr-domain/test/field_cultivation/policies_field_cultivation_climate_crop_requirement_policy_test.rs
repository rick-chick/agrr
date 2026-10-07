// Tests for field_cultivation_climate_crop_requirement_policy.

use serde_json::json;

use crate::field_cultivation::dtos::{
    ClimateCropEntity, ClimateCropStage, ClimateTemperatureRequirement, ClimateThermalRequirement,
    FieldCultivationClimateFailureReason,
};
use crate::field_cultivation::policies::validate_crop_requirement_for_climate;

fn sample_stage(order: i32, with_temperature: bool, with_thermal: bool) -> ClimateCropStage {
    ClimateCropStage {
        name: format!("Stage {order}"),
        order,
        temperature_requirement: with_temperature.then_some(ClimateTemperatureRequirement {
            base_temperature: 10.0,
            optimal_min: Some(15.0),
            optimal_max: Some(25.0),
            low_stress_threshold: None,
            high_stress_threshold: None,
            frost_threshold: None,
            max_temperature: Some(50.0),
        }),
        thermal_requirement: with_thermal.then_some(ClimateThermalRequirement {
            required_gdd: 100.0,
        }),
    }
}

#[test]
fn accepts_crop_with_complete_lowest_order_stage() {
    let crop = ClimateCropEntity {
        id: 1,
        name: "Tomato".into(),
        variety: None,
        area_per_unit: None,
        revenue_per_area: None,
        groups: json!([]),
        is_reference: true,
        user_id: None,
        crop_stages: vec![sample_stage(1, true, true)],
    };
    validate_crop_requirement_for_climate(&crop).expect("valid crop");
}

#[test]
fn rejects_crop_with_no_valid_stages() {
    let crop = ClimateCropEntity {
        id: 1,
        name: "Tomato".into(),
        variety: None,
        area_per_unit: None,
        revenue_per_area: None,
        groups: json!([]),
        is_reference: true,
        user_id: None,
        crop_stages: vec![sample_stage(1, false, false)],
    };
    let err = validate_crop_requirement_for_climate(&crop).expect_err("incomplete crop");
    assert_eq!(
        err.0.reason,
        FieldCultivationClimateFailureReason::CropRequirementIncomplete
    );
}

#[test]
fn rejects_when_lowest_order_stage_lacks_temperature() {
    let crop = ClimateCropEntity {
        id: 1,
        name: "Tomato".into(),
        variety: None,
        area_per_unit: None,
        revenue_per_area: None,
        groups: json!([]),
        is_reference: true,
        user_id: None,
        crop_stages: vec![
            sample_stage(1, false, true),
            sample_stage(2, true, true),
        ],
    };
    let err = validate_crop_requirement_for_climate(&crop).expect_err("missing base temp");
    assert_eq!(
        err.0.reason,
        FieldCultivationClimateFailureReason::CropRequirementIncomplete
    );
}
