use crate::agricultural_task::constants::schedule_item_types::FIELD_WORK;
use crate::crop::dtos::{
    CropTaskScheduleBlueprintPersistAttrs, MastersCropTaskScheduleBlueprint,
    MastersCropTaskScheduleBlueprintCreateInput,
};
use crate::crop::policies::masters_crop_task_schedule_blueprint_duplicate_policy;

pub const MANUAL_BLUEPRINT_SOURCE: &str = "manual";

pub fn duplicate(
    existing: &[MastersCropTaskScheduleBlueprint],
    stage_order: Option<i32>,
    agricultural_task_id: i64,
    gdd_trigger: Option<f64>,
) -> bool {
    masters_crop_task_schedule_blueprint_duplicate_policy::conflicts_with_existing(
        existing,
        None,
        agricultural_task_id,
        stage_order,
        gdd_trigger,
    )
}

pub fn build_persist_attributes(
    input: &MastersCropTaskScheduleBlueprintCreateInput,
    agricultural_task_id: i64,
    stage_order: Option<i32>,
    gdd_trigger: Option<f64>,
    agricultural_task: &crate::agricultural_task::entities::AgriculturalTaskEntity,
) -> CropTaskScheduleBlueprintPersistAttrs {
    CropTaskScheduleBlueprintPersistAttrs {
        crop_id: input.crop_id,
        blueprint_id: None,
        agricultural_task_id: Some(agricultural_task_id),
        source_agricultural_task_id: None,
        stage_order,
        stage_name: input.stage_name.clone(),
        gdd_trigger: gdd_trigger.map(|v| v.to_string()),
        gdd_tolerance: None,
        task_type: input
            .task_type
            .clone()
            .filter(|value| !value.trim().is_empty())
            .unwrap_or_else(|| {
                agricultural_task
                    .task_type
                    .clone()
                    .filter(|value| !value.trim().is_empty())
                    .unwrap_or_else(|| FIELD_WORK.to_string())
            }),
        source: MANUAL_BLUEPRINT_SOURCE.to_string(),
        priority: input.priority.unwrap_or(1),
        amount: None,
        amount_unit: None,
        description: input
            .description
            .clone()
            .or_else(|| agricultural_task.description.clone()),
        weather_dependency: agricultural_task.weather_dependency.clone(),
        time_per_sqm: agricultural_task.time_per_sqm.map(|v| v.to_string()),
        name: Some(agricultural_task.name.clone()),
    }
}

#[cfg(test)]
mod masters_crop_task_schedule_blueprint_create_policy_test_inline {
    use super::*;
    use crate::agricultural_task::entities::AgriculturalTaskEntity;
    use crate::crop::dtos::MastersCropTaskScheduleBlueprintCreateInput;

    fn task() -> AgriculturalTaskEntity {
        AgriculturalTaskEntity {
            id: Some(3),
            user_id: Some(1),
            name: "除草".into(),
            description: Some("desc".into()),
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: vec![],
            skill_level: None,
            region: None,
            task_type: Some("field_work".into()),
            is_reference: false,
            created_at: None,
            updated_at: None,
        }
    }

    #[test]
    fn build_persist_attributes_sets_task_name() {
        let input = MastersCropTaskScheduleBlueprintCreateInput {
            user_id: 1,
            crop_id: 2,
            agricultural_task_id: Some(3),
            stage_order: None,
            stage_name: None,
            gdd_trigger: None,
            task_type: None,
            priority: None,
            description: None,
        };
        let attrs = build_persist_attributes(&input, 3, None, None, &task());
        assert_eq!(attrs.name.as_deref(), Some("除草"));
    }
}
