use crate::agricultural_task::constants::schedule_item_types::FIELD_WORK;
use crate::crop::dtos::{
    CropTaskScheduleBlueprintPersistAttrs, MastersCropTaskScheduleBlueprint,
    MastersCropTaskScheduleBlueprintCreateInput,
};

pub const MANUAL_BLUEPRINT_SOURCE: &str = "manual";

pub fn duplicate(
    existing: &[MastersCropTaskScheduleBlueprint],
    stage_order: i32,
    agricultural_task_id: i64,
) -> bool {
    existing.iter().any(|row| {
        row.stage_order == stage_order && row.agricultural_task_id == Some(agricultural_task_id)
    })
}

pub fn build_persist_attributes(
    input: &MastersCropTaskScheduleBlueprintCreateInput,
    agricultural_task_id: i64,
    stage_order: i32,
    gdd_trigger: f64,
) -> CropTaskScheduleBlueprintPersistAttrs {
    CropTaskScheduleBlueprintPersistAttrs {
        crop_id: input.crop_id,
        agricultural_task_id: Some(agricultural_task_id),
        source_agricultural_task_id: None,
        stage_order,
        stage_name: input.stage_name.clone(),
        gdd_trigger: gdd_trigger.to_string(),
        gdd_tolerance: None,
        task_type: input
            .task_type
            .clone()
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| FIELD_WORK.to_string()),
        source: MANUAL_BLUEPRINT_SOURCE.to_string(),
        priority: input.priority.unwrap_or(1),
        amount: None,
        amount_unit: None,
        description: input.description.clone(),
        weather_dependency: None,
        time_per_sqm: None,
    }
}
