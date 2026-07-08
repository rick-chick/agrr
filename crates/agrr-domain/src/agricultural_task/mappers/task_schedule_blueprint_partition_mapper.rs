//! Partitions task schedule blueprints into general field work and fertilizer categories.

use crate::agricultural_task::constants::schedule_item_types::{
    BASAL_FERTILIZATION, FIELD_WORK, TOPDRESS_FERTILIZATION,
};
use crate::agricultural_task::gateways::TaskScheduleBlueprint;

pub fn partition_blueprints(
    blueprints: &[TaskScheduleBlueprint],
) -> (Vec<&TaskScheduleBlueprint>, Vec<&TaskScheduleBlueprint>) {
    let mut general = Vec::new();
    let mut fertilizer = Vec::new();
    for blueprint in blueprints {
        match blueprint.task_type.as_str() {
            FIELD_WORK => general.push(blueprint),
            BASAL_FERTILIZATION | TOPDRESS_FERTILIZATION => fertilizer.push(blueprint),
            _ => {}
        }
    }
    (general, fertilizer)
}

#[cfg(test)]
mod task_schedule_blueprint_partition_mapper_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/agricultural_task/task_schedule_blueprint_partition_mapper_test.rs"
    ));
}
