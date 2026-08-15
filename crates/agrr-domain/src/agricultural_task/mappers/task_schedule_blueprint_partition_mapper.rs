//! Partitions task schedule blueprints into general field work, fertilizer, and pest control categories.

use crate::agricultural_task::constants::schedule_item_types::{
    BASAL_FERTILIZATION, CURATIVE_SPRAY, FIELD_WORK, PREVENTIVE_SPRAY, TOPDRESS_FERTILIZATION,
};
use crate::agricultural_task::gateways::TaskScheduleBlueprint;

pub fn partition_blueprints(
    blueprints: &[TaskScheduleBlueprint],
) -> (
    Vec<&TaskScheduleBlueprint>,
    Vec<&TaskScheduleBlueprint>,
    Vec<&TaskScheduleBlueprint>,
) {
    let mut general = Vec::new();
    let mut fertilizer = Vec::new();
    let mut pest_control = Vec::new();
    for blueprint in blueprints {
        match blueprint.task_type.as_str() {
            FIELD_WORK => general.push(blueprint),
            BASAL_FERTILIZATION | TOPDRESS_FERTILIZATION => fertilizer.push(blueprint),
            PREVENTIVE_SPRAY | CURATIVE_SPRAY => pest_control.push(blueprint),
            _ => {}
        }
    }
    (general, fertilizer, pest_control)
}

#[cfg(test)]
mod task_schedule_blueprint_partition_mapper_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/agricultural_task/task_schedule_blueprint_partition_mapper_test.rs"
    ));
}
