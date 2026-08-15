// Tests for `mappers/task_schedule_blueprint_partition_mapper.rs`.

use crate::agricultural_task::constants::schedule_item_types::{
    BASAL_FERTILIZATION, CURATIVE_SPRAY, FIELD_WORK, PREVENTIVE_SPRAY, TOPDRESS_FERTILIZATION,
};
use crate::agricultural_task::gateways::TaskScheduleBlueprint;

fn blueprint(task_type: &str) -> TaskScheduleBlueprint {
    TaskScheduleBlueprint {
        task_type: task_type.into(),
        gdd_trigger: None,
        gdd_tolerance: None,
        description: None,
        stage_name: None,
        stage_order: None,
        priority: None,
        source: None,
        weather_dependency: None,
        time_per_sqm: None,
        amount: None,
        amount_unit: None,
        agricultural_task: None,
    }
}

#[test]
fn partition_blueprints_splits_field_work_and_fertilizer() {
    let blueprints = vec![
        blueprint(FIELD_WORK),
        blueprint(BASAL_FERTILIZATION),
        blueprint(TOPDRESS_FERTILIZATION),
        blueprint("unknown_type"),
    ];

    let (general, fertilizer, pest_control) = partition_blueprints(blueprints.as_slice());

    assert_eq!(general.len(), 1);
    assert_eq!(general[0].task_type, FIELD_WORK);
    assert_eq!(fertilizer.len(), 2);
    assert_eq!(fertilizer[0].task_type, BASAL_FERTILIZATION);
    assert_eq!(fertilizer[1].task_type, TOPDRESS_FERTILIZATION);
    assert!(pest_control.is_empty());
}

#[test]
fn partition_blueprints_splits_pest_control_spray_types() {
    let blueprints = vec![
        blueprint(FIELD_WORK),
        blueprint(PREVENTIVE_SPRAY),
        blueprint(CURATIVE_SPRAY),
    ];

    let (general, fertilizer, pest_control) = partition_blueprints(blueprints.as_slice());

    assert_eq!(general.len(), 1);
    assert_eq!(fertilizer.len(), 0);
    assert_eq!(pest_control.len(), 2);
    assert_eq!(pest_control[0].task_type, PREVENTIVE_SPRAY);
    assert_eq!(pest_control[1].task_type, CURATIVE_SPRAY);
}
