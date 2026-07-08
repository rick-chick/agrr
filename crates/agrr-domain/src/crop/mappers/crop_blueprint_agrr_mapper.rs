use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::crop::dtos::MastersCropTaskScheduleBlueprint;
use crate::crop::mappers::blueprint_attribute_lookup::merge_blueprint_task_attributes;
use serde_json::{json, Value};

/// Build agrr schedule CLI input from blueprint rows joined with agricultural task master.
pub fn to_agrr_format(
    blueprint: &MastersCropTaskScheduleBlueprint,
    agricultural_task: &AgriculturalTaskEntity,
) -> Value {
    let name = blueprint
        .name
        .clone()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| agricultural_task.name.clone());
    let attributes = merge_blueprint_task_attributes(blueprint, Some(agricultural_task));
    let description = attributes.description;
    let weather_dependency = attributes.weather_dependency;
    let skill_level = agricultural_task.skill_level.clone();
    let required_tools = agricultural_task.required_tools.clone();
    let time_per_sqm = attributes
        .time_per_sqm
        .and_then(|v| v.to_string().parse::<f64>().ok())
        .or(agricultural_task.time_per_sqm);

    let mut obj = json!({
        "task_id": blueprint.id.to_string(),
        "blueprint_id": blueprint.id.to_string(),
        "name": name,
        "description": description,
        "weather_dependency": weather_dependency,
        "required_tools": required_tools,
        "skill_level": skill_level,
    });
    if let Some(t) = time_per_sqm {
        if let Some(obj_map) = obj.as_object_mut() {
            obj_map.insert("time_per_sqm".into(), json!(t));
        }
    }
    omit_nulls(obj)
}

pub fn to_agrr_format_array(
    blueprints: &[MastersCropTaskScheduleBlueprint],
    agricultural_tasks: &[AgriculturalTaskEntity],
) -> Vec<Value> {
    blueprints
        .iter()
        .filter_map(|blueprint| {
            let task_id = blueprint.agricultural_task_id?;
            let agricultural_task = agricultural_tasks
                .iter()
                .find(|task| task.id == Some(task_id))?;
            Some(to_agrr_format(blueprint, agricultural_task))
        })
        .collect()
}

fn omit_nulls(mut value: Value) -> Value {
    if let Some(obj) = value.as_object_mut() {
        obj.retain(|_, v| !v.is_null());
    }
    value
}

#[cfg(test)]
mod crop_blueprint_agrr_mapper_test_inline {
    use super::*;
    use rust_decimal::Decimal;
    use std::str::FromStr;

    #[test]
    fn to_agrr_format_uses_blueprint_id_as_task_id() {
        let blueprint = MastersCropTaskScheduleBlueprint {
            id: 17,
            crop_id: 2,
            agricultural_task_id: Some(42),
            source_agricultural_task_id: None,
            stage_order: None,
            stage_name: None,
            gdd_trigger: None,
            gdd_tolerance: None,
            task_type: "field_work".into(),
            source: "manual".into(),
            priority: 1,
            amount: None,
            amount_unit: None,
            description: Some("bp desc".into()),
            weather_dependency: None,
            time_per_sqm: None,
            name: None,
            created_at: None,
            updated_at: None,
        };
        let agricultural_task = AgriculturalTaskEntity {
            id: Some(42),
            user_id: Some(1),
            name: "除草".into(),
            description: Some("task desc".into()),
            time_per_sqm: Some(0.5),
            weather_dependency: Some("low".into()),
            required_tools: vec!["hoe".into()],
            skill_level: Some("beginner".into()),
            region: None,
            task_type: Some("field_work".into()),
            is_reference: false,
            created_at: None,
            updated_at: None,
        };
        let fmt = to_agrr_format(&blueprint, &agricultural_task);
        assert_eq!(fmt["task_id"], "17");
        assert_eq!(fmt["blueprint_id"], "17");
        assert_eq!(fmt["name"], "除草");
        assert_eq!(fmt["time_per_sqm"], 0.5_f64);
    }

    #[test]
    fn to_agrr_format_prefers_blueprint_attributes_over_task_master() {
        let blueprint = MastersCropTaskScheduleBlueprint {
            id: 1,
            crop_id: 2,
            agricultural_task_id: Some(42),
            source_agricultural_task_id: None,
            stage_order: None,
            stage_name: None,
            gdd_trigger: None,
            gdd_tolerance: None,
            task_type: "field_work".into(),
            source: "manual".into(),
            priority: 1,
            amount: None,
            amount_unit: None,
            description: Some("bp desc".into()),
            weather_dependency: Some("high".into()),
            time_per_sqm: Some(Decimal::from_str("2.0").unwrap()),
            name: None,
            created_at: None,
            updated_at: None,
        };
        let agricultural_task = AgriculturalTaskEntity {
            id: Some(42),
            user_id: Some(1),
            name: "除草".into(),
            description: Some("task desc".into()),
            time_per_sqm: Some(0.5),
            weather_dependency: Some("low".into()),
            required_tools: vec![],
            skill_level: None,
            region: None,
            task_type: Some("field_work".into()),
            is_reference: false,
            created_at: None,
            updated_at: None,
        };
        let fmt = to_agrr_format(&blueprint, &agricultural_task);
        assert_eq!(fmt["description"], "bp desc");
        assert_eq!(fmt["weather_dependency"], "high");
        assert_eq!(fmt["time_per_sqm"], 2.0_f64);
    }

    #[test]
    fn to_agrr_format_array_skips_blueprints_without_matching_task() {
        let blueprint = MastersCropTaskScheduleBlueprint {
            id: 1,
            crop_id: 2,
            agricultural_task_id: Some(99),
            source_agricultural_task_id: None,
            stage_order: None,
            stage_name: None,
            gdd_trigger: None,
            gdd_tolerance: None,
            task_type: "field_work".into(),
            source: "manual".into(),
            priority: 1,
            amount: None,
            amount_unit: None,
            description: None,
            weather_dependency: None,
            time_per_sqm: None,
            name: None,
            created_at: None,
            updated_at: None,
        };
        let rows = to_agrr_format_array(&[blueprint], &[]);
        assert!(rows.is_empty());
    }
}
