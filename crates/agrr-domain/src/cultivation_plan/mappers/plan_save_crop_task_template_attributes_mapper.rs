//! Ruby: `Domain::CultivationPlan::Mappers::PlanSaveCropTaskTemplateAttributesMapper`

use std::collections::BTreeMap;

use serde_json::{json, Value};

use crate::cultivation_plan::dtos::{
    PublicPlanSaveAgriculturalTaskReferenceRow, PublicPlanSaveCropTaskTemplateLinkRow,
};

pub fn attributes_for_create(
    link_row: &PublicPlanSaveCropTaskTemplateLinkRow,
    task_row: &PublicPlanSaveAgriculturalTaskReferenceRow,
    user_task_name: Option<&str>,
) -> BTreeMap<String, Value> {
    let name = user_task_name
        .filter(|s| !s.is_empty())
        .or(link_row.name.as_deref().filter(|s| !s.is_empty()))
        .or(task_row.name.as_deref())
        .map(str::to_string);

    BTreeMap::from([
        ("name".into(), json!(name)),
        (
            "description".into(),
            json!(link_row
                .description
                .clone()
                .or_else(|| task_row.description.clone())),
        ),
        (
            "time_per_sqm".into(),
            json!(link_row.time_per_sqm.or(task_row.time_per_sqm)),
        ),
        (
            "weather_dependency".into(),
            json!(link_row
                .weather_dependency
                .clone()
                .or_else(|| task_row.weather_dependency.clone())),
        ),
        (
            "required_tools".into(),
            json!(tools_for_create(link_row, task_row)),
        ),
        (
            "skill_level".into(),
            json!(link_row.skill_level.clone().or_else(|| task_row.skill_level.clone())),
        ),
        (
            "task_type".into(),
            json!(link_row.task_type.clone().or_else(|| task_row.task_type.clone())),
        ),
        (
            "task_type_id".into(),
            json!(link_row.task_type_id.or(task_row.task_type_id)),
        ),
        ("is_reference".into(), json!(link_row.is_reference)),
    ])
}

fn tools_for_create(
    link_row: &PublicPlanSaveCropTaskTemplateLinkRow,
    task_row: &PublicPlanSaveAgriculturalTaskReferenceRow,
) -> Vec<String> {
    link_row
        .required_tools
        .clone()
        .or_else(|| task_row.required_tools.clone())
        .unwrap_or_default()
}
