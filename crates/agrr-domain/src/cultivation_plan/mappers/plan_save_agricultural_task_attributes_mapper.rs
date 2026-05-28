//! Ruby: `Domain::CultivationPlan::Mappers::PlanSaveAgriculturalTaskAttributesMapper`

use std::collections::BTreeMap;

use serde_json::{json, Value};

use crate::cultivation_plan::dtos::PublicPlanSaveAgriculturalTaskReferenceRow;

pub fn attributes_for_create(
    row: &PublicPlanSaveAgriculturalTaskReferenceRow,
    region: Option<&str>,
) -> BTreeMap<String, Value> {
    BTreeMap::from([
        ("name".into(), json!(row.name)),
        ("description".into(), json!(row.description)),
        ("time_per_sqm".into(), json!(row.time_per_sqm)),
        ("weather_dependency".into(), json!(row.weather_dependency)),
        (
            "required_tools".into(),
            json!(row.required_tools.clone().unwrap_or_default()),
        ),
        ("skill_level".into(), json!(row.skill_level)),
        ("task_type".into(), json!(row.task_type)),
        ("task_type_id".into(), json!(row.task_type_id)),
        (
            "region".into(),
            json!(row
                .region
                .clone()
                .or_else(|| region.map(str::to_string))),
        ),
        ("is_reference".into(), json!(false)),
        (
            "source_agricultural_task_id".into(),
            json!(row.reference_agricultural_task_id),
        ),
    ])
}
