//! Resolves display names for task schedule items from blueprint and related task snapshots.

use crate::agricultural_task::constants::schedule_item_default_names::{
    BASAL_FERTILIZATION_NAME, FIELD_TASK_NAME, TOPDRESS_FERTILIZATION_NAME,
};
use crate::agricultural_task::constants::schedule_item_types::{
    BASAL_FERTILIZATION, TOPDRESS_FERTILIZATION,
};
use crate::agricultural_task::gateways::{TaskScheduleBlueprint, TaskScheduleRelatedTask};

pub fn name_for_blueprint(
    blueprint: &TaskScheduleBlueprint,
    task: Option<&TaskScheduleRelatedTask>,
) -> String {
    if let Some(task) = task {
        if !task.name.trim().is_empty() {
            return task.name.clone();
        }
    }
    if let Some(ref desc) = blueprint.description {
        if !desc.trim().is_empty() {
            return desc.clone();
        }
    }
    match blueprint.task_type.as_str() {
        BASAL_FERTILIZATION => BASAL_FERTILIZATION_NAME.into(),
        TOPDRESS_FERTILIZATION => TOPDRESS_FERTILIZATION_NAME.into(),
        _ => FIELD_TASK_NAME.into(),
    }
}

#[cfg(test)]
mod task_schedule_item_name_mapper_test_inline {
    use super::*;
    use crate::agricultural_task::constants::schedule_item_types::FIELD_WORK;

    fn blueprint(task_type: &str, description: Option<&str>) -> TaskScheduleBlueprint {
        TaskScheduleBlueprint {
            task_type: task_type.into(),
            gdd_trigger: None,
            gdd_tolerance: None,
            description: description.map(str::to_string),
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

    fn related_task(name: &str) -> TaskScheduleRelatedTask {
        TaskScheduleRelatedTask {
            id: 1,
            name: name.into(),
            description: None,
            weather_dependency: None,
            time_per_sqm: None,
        }
    }

    #[test]
    fn prefers_related_task_name() {
        let bp = blueprint(BASAL_FERTILIZATION, Some("desc"));
        assert_eq!(
            name_for_blueprint(&bp, Some(&related_task("基肥"))),
            "基肥"
        );
    }

    #[test]
    fn falls_back_to_blueprint_description_when_task_name_blank() {
        let bp = blueprint(TOPDRESS_FERTILIZATION, Some("追肥作業"));
        assert_eq!(
            name_for_blueprint(&bp, Some(&related_task("  "))),
            "追肥作業"
        );
    }

    #[test]
    fn falls_back_to_task_type_default_names() {
        assert_eq!(
            name_for_blueprint(&blueprint(BASAL_FERTILIZATION, None), None),
            BASAL_FERTILIZATION_NAME
        );
        assert_eq!(
            name_for_blueprint(&blueprint(TOPDRESS_FERTILIZATION, None), None),
            TOPDRESS_FERTILIZATION_NAME
        );
        assert_eq!(
            name_for_blueprint(&blueprint(FIELD_WORK, None), None),
            FIELD_TASK_NAME
        );
    }
}
