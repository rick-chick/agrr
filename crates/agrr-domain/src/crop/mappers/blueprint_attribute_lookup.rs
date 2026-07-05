use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::crop::dtos::MastersCropTaskScheduleBlueprint;
use crate::crop::mappers::task_schedule_blueprint_generator::BlueprintAttributeSnapshot;
use rust_decimal::Decimal;
use std::collections::HashMap;

/// Merge blueprint attribute fields with agricultural task master fallbacks.
pub fn merge_blueprint_task_attributes(
    blueprint: &MastersCropTaskScheduleBlueprint,
    agricultural_task: Option<&AgriculturalTaskEntity>,
) -> BlueprintAttributeSnapshot {
    let description = blueprint
        .description
        .clone()
        .or_else(|| agricultural_task.and_then(|task| task.description.clone()));
    let weather_dependency = blueprint
        .weather_dependency
        .clone()
        .or_else(|| agricultural_task.and_then(|task| task.weather_dependency.clone()));
    let time_per_sqm = blueprint.time_per_sqm.or_else(|| {
        agricultural_task.and_then(|task| {
            task.time_per_sqm
                .and_then(|v| Decimal::from_str_exact(&v.to_string()).ok())
        })
    });
    BlueprintAttributeSnapshot {
        description,
        weather_dependency,
        time_per_sqm,
    }
}

/// Build per-task attribute snapshots from blueprint rows merged with agricultural task master.
pub fn build_attribute_lookup(
    blueprints: &[MastersCropTaskScheduleBlueprint],
    agricultural_tasks: &[AgriculturalTaskEntity],
) -> HashMap<i64, BlueprintAttributeSnapshot> {
    let mut lookup = HashMap::new();
    for blueprint in blueprints {
        let Some(task_id) = blueprint.agricultural_task_id else {
            continue;
        };
        let agricultural_task = agricultural_tasks
            .iter()
            .find(|task| task.id == Some(task_id));
        lookup.insert(
            task_id,
            merge_blueprint_task_attributes(blueprint, agricultural_task),
        );
    }
    lookup
}

#[cfg(test)]
mod blueprint_attribute_lookup_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/crop/blueprint_attribute_lookup_test.rs"
    ));
}
