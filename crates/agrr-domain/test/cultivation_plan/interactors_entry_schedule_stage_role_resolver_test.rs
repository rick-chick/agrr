// Tests for `interactors/entry_schedule/stage_role_resolver.rs` (Ruby parity under test/domain/cultivation_plan/).

use crate::cultivation_plan::interactors::entry_schedule::{
    CropStageSnapshot, StageRoleResolver, TemperatureRequirementSnapshot,
};

fn stage(id: i64, name: &str, order: i32) -> CropStageSnapshot {
    CropStageSnapshot {
        id,
        name: name.into(),
        order,
        temperature_requirement: Some(TemperatureRequirementSnapshot {
            frost_threshold: None,
            optimal_min: Some(10.0),
            optimal_max: Some(20.0),
            base_temperature: Some(5.0),
        }),
    }
}

// Ruby R0: sowing_stage returns minimum order
#[test]
fn sowing_stage_returns_minimum_order() {
    let stages = vec![stage(2, "生育", 2), stage(1, "播種", 1)];
    let sow = StageRoleResolver::sowing_stage(&stages).unwrap();
    assert_eq!(sow.id, 1);
    assert_eq!(sow.name, "播種");
}

// Ruby R0: transplant_stage prefers name match
#[test]
fn transplant_stage_prefers_name_with_transplant_pattern() {
    let stages = vec![
        stage(1, "播種", 1),
        stage(2, "定植", 2),
        stage(3, "収穫", 3),
    ];
    let tr = StageRoleResolver::transplant_stage(&stages).unwrap();
    assert_eq!(tr.id, 2);
}

// Ruby R0: transplant_stage falls back to second ordered stage
#[test]
fn transplant_stage_falls_back_to_second_stage() {
    let stages = vec![stage(1, "播種", 1), stage(2, "生育", 2)];
    let tr = StageRoleResolver::transplant_stage(&stages).unwrap();
    assert_eq!(tr.id, 2);
}
