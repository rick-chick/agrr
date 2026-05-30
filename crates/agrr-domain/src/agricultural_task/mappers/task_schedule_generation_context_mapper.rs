//! Ruby: `Domain::CultivationPlan::Mappers::TaskScheduleGenerationContextMapper`

use std::collections::HashMap;

use crate::agricultural_task::gateways::{
    TaskScheduleBlueprint, TaskScheduleBlueprintRow, TaskScheduleCrop, TaskScheduleCropRow,
    TaskScheduleCropTaskTemplate, TaskScheduleFieldCultivation, TaskScheduleFieldCultivationRow,
    TaskSchedulePlan, TaskSchedulePlanContext, TaskSchedulePlanRow,
    TaskScheduleTemplateRow,
};

pub fn assemble(
    plan_row: TaskSchedulePlanRow,
    field_cultivation_rows: Vec<TaskScheduleFieldCultivationRow>,
    crop_rows_by_id: HashMap<i64, TaskScheduleCropRow>,
    template_rows_by_crop_id: HashMap<i64, Vec<TaskScheduleTemplateRow>>,
    blueprint_rows_by_crop_id: HashMap<i64, Vec<TaskScheduleBlueprintRow>>,
    agrr_requirement_by_crop_id: HashMap<i64, serde_json::Value>,
) -> TaskSchedulePlanContext {
    let field_cultivations = field_cultivation_rows
        .into_iter()
        .filter_map(|fc_row| {
            let crop_id = fc_row.crop_id?;
            let crop_row = crop_rows_by_id.get(&crop_id)?;
            let templates = template_rows_by_crop_id.get(&crop_id).cloned().unwrap_or_default();
            let blueprints = blueprint_rows_by_crop_id.get(&crop_id).cloned().unwrap_or_default();
            let agrr_requirement = agrr_requirement_by_crop_id.get(&crop_id).cloned();

            let crop = crop_snapshot_from(
                crop_row,
                templates,
                blueprints,
                agrr_requirement,
            );

            Some(TaskScheduleFieldCultivation {
                id: fc_row.id,
                start_date: fc_row.start_date,
                crop: Some(crop),
            })
        })
        .collect();

    let plan = TaskSchedulePlan {
        id: plan_row.id,
        predicted_weather_data: plan_row.predicted_weather_data,
        calculated_planning_start_date: plan_row.calculated_planning_start_date,
        field_cultivations,
    };

    TaskSchedulePlanContext { plan }
}

fn crop_snapshot_from(
    crop_row: &TaskScheduleCropRow,
    template_rows: Vec<TaskScheduleTemplateRow>,
    blueprint_rows: Vec<TaskScheduleBlueprintRow>,
    _agrr_requirement: Option<serde_json::Value>,
) -> TaskScheduleCrop {
    let crop_task_templates = template_rows
        .into_iter()
        .map(|row| TaskScheduleCropTaskTemplate {
            agricultural_task: row.agricultural_task,
        })
        .collect();

    let crop_task_schedule_blueprints = blueprint_rows
        .into_iter()
        .map(|row| TaskScheduleBlueprint {
            task_type: row.task_type,
            gdd_trigger: row.gdd_trigger,
            gdd_tolerance: row.gdd_tolerance,
            description: row.description,
            stage_name: row.stage_name,
            stage_order: row.stage_order,
            priority: row.priority,
            source: row.source,
            weather_dependency: row.weather_dependency,
            time_per_sqm: row.time_per_sqm,
            amount: row.amount,
            amount_unit: row.amount_unit,
            agricultural_task: row.agricultural_task,
        })
        .collect();

    TaskScheduleCrop {
        id: crop_row.id,
        name: crop_row.name.clone(),
        crop_task_templates,
        crop_task_schedule_blueprints,
    }
}
