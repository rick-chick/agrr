//! Validates and normalizes external skill setup proposal JSON.

use crate::agricultural_task::constants::schedule_item_types::{
    BASAL_FERTILIZATION, FIELD_WORK, TOPDRESS_FERTILIZATION,
};
use crate::crop::dtos::{
    CropSetupProposalAgriculturalTaskPlan, CropSetupProposalBlueprintPlan,
    CropSetupProposalPlan, CropSetupProposalStagePlan, CropSetupProposalValidationError,
    MastersCropTaskScheduleBlueprint,
};
use crate::crop::entities::CropStageEntity;
use serde_json::{json, Map, Value};
use std::collections::HashSet;

const ALLOWED_REGIONS: &[&str] = &["jp", "us", "in"];
const ALLOWED_TASK_TYPES: &[&str] = &[
    FIELD_WORK,
    BASAL_FERTILIZATION,
    TOPDRESS_FERTILIZATION,
];

pub fn validate_and_normalize(
    body: &Value,
    _existing_blueprints: &[MastersCropTaskScheduleBlueprint],
    existing_stages: &[CropStageEntity],
) -> Result<(CropSetupProposalPlan, Value), Vec<CropSetupProposalValidationError>> {
    let mut errors = Vec::new();

    let stages_value = body.get("stages").and_then(|v| v.as_array());
    let tasks_value = body.get("agricultural_tasks").and_then(|v| v.as_array());
    let blueprints_value = body
        .get("task_schedule_blueprints")
        .and_then(|v| v.as_array());

    let empty_stages: Vec<Value> = Vec::new();
    let stages_raw = match stages_value {
        Some(items) if !items.is_empty() => items,
        Some(_) => {
            errors.push(CropSetupProposalValidationError::new(
                "stages",
                "must contain at least one stage",
            ));
            &empty_stages
        }
        None => {
            errors.push(CropSetupProposalValidationError::new(
                "stages",
                "is required",
            ));
            &empty_stages
        }
    };

    let empty_tasks: Vec<Value> = Vec::new();
    let tasks_raw = match tasks_value {
        Some(items) => items,
        None => {
            errors.push(CropSetupProposalValidationError::new(
                "agricultural_tasks",
                "is required",
            ));
            &empty_tasks
        }
    };

    let empty_blueprints: Vec<Value> = Vec::new();
    let blueprints_raw = match blueprints_value {
        Some(items) => items,
        None => {
            errors.push(CropSetupProposalValidationError::new(
                "task_schedule_blueprints",
                "is required",
            ));
            &empty_blueprints
        }
    };

    let mut stages = Vec::new();
    let mut stage_orders = HashSet::new();
    for (index, stage) in stages_raw.iter().enumerate() {
        let prefix = format!("stages[{index}]");
        let Some(obj) = stage.as_object() else {
            errors.push(CropSetupProposalValidationError::new(
                prefix,
                "must be an object",
            ));
            continue;
        };

        let name = required_string(obj, "name", &prefix, &mut errors);
        let order = required_i32(obj, "order", &prefix, &mut errors);
        if let Some(order) = order {
            if order <= 0 {
                errors.push(CropSetupProposalValidationError::new(
                    format!("{prefix}.order"),
                    "must be greater than 0",
                ));
            } else if !stage_orders.insert(order) {
                errors.push(CropSetupProposalValidationError::new(
                    format!("{prefix}.order"),
                    "duplicate stage order in proposal",
                ));
            }
            for existing in existing_stages {
                if existing.order == order {
                    errors.push(CropSetupProposalValidationError::new(
                        format!("{prefix}.order"),
                        "conflicts with an existing crop stage order",
                    ));
                }
            }
        }

        let thermal = obj.get("thermal_requirement");
        let required_gdd = thermal.and_then(|v| parse_required_gdd(v));
        if required_gdd.is_none() {
            errors.push(CropSetupProposalValidationError::new(
                format!("{prefix}.thermal_requirement.required_gdd"),
                "is required",
            ));
        }

        if let (Some(name), Some(order), Some(thermal_value)) = (name, order, thermal.cloned()) {
            stages.push(CropSetupProposalStagePlan {
                name,
                order,
                temperature_requirement: optional_object(obj, "temperature_requirement"),
                thermal_requirement: thermal_value,
                sunshine_requirement: optional_object(obj, "sunshine_requirement"),
                nutrient_requirement: optional_object(obj, "nutrient_requirement"),
            });
        }
    }

    let mut task_refs = HashSet::new();
    let mut agricultural_tasks = Vec::new();
    for (index, task) in tasks_raw.iter().enumerate() {
        let prefix = format!("agricultural_tasks[{index}]");
        let Some(obj) = task.as_object() else {
            errors.push(CropSetupProposalValidationError::new(
                prefix,
                "must be an object",
            ));
            continue;
        };

        let ref_key = required_string(obj, "ref", &prefix, &mut errors);
        let name = required_string(obj, "name", &prefix, &mut errors);
        let region = required_string(obj, "region", &prefix, &mut errors);
        let task_type = required_string(obj, "task_type", &prefix, &mut errors);

        if let Some(region) = region.as_deref() {
            if !ALLOWED_REGIONS.contains(&region) {
                errors.push(CropSetupProposalValidationError::new(
                    format!("{prefix}.region"),
                    "must be one of jp, us, in",
                ));
            }
        }
        if let Some(task_type) = task_type.as_deref() {
            if !ALLOWED_TASK_TYPES.contains(&task_type) {
                errors.push(CropSetupProposalValidationError::new(
                    format!("{prefix}.task_type"),
                    "must be field_work, basal_fertilization, or topdress_fertilization",
                ));
            }
        }
        if let Some(ref_key) = ref_key.as_deref() {
            if ref_key.trim().is_empty() {
                errors.push(CropSetupProposalValidationError::new(
                    format!("{prefix}.ref"),
                    "cannot be blank",
                ));
            } else if !task_refs.insert(ref_key.to_string()) {
                errors.push(CropSetupProposalValidationError::new(
                    format!("{prefix}.ref"),
                    "duplicate ref in proposal",
                ));
            }
        }

        if let (Some(ref_key), Some(name), Some(region), Some(task_type)) =
            (ref_key, name, region, task_type)
        {
            agricultural_tasks.push(CropSetupProposalAgriculturalTaskPlan {
                ref_key,
                name,
                description: optional_string(obj, "description"),
                time_per_sqm: optional_f64(obj, "time_per_sqm"),
                skill_level: optional_string(obj, "skill_level"),
                region,
                task_type,
            });
        }
    }

    let proposal_stage_orders: HashSet<i32> = stages.iter().map(|s| s.order).collect();
    let mut task_schedule_blueprints = Vec::new();
    let mut seen_blueprint_keys = HashSet::new();

    for (index, blueprint) in blueprints_raw.iter().enumerate() {
        let prefix = format!("task_schedule_blueprints[{index}]");
        let Some(obj) = blueprint.as_object() else {
            errors.push(CropSetupProposalValidationError::new(
                prefix,
                "must be an object",
            ));
            continue;
        };

        let agricultural_task_ref =
            required_string(obj, "agricultural_task_ref", &prefix, &mut errors);
        let stage_order = required_i32(obj, "stage_order", &prefix, &mut errors);
        let gdd_trigger = required_f64(obj, "gdd_trigger", &prefix, &mut errors);
        let task_type = required_string(obj, "task_type", &prefix, &mut errors);
        let priority = obj
            .get("priority")
            .and_then(|v| v.as_i64())
            .map(|v| v as i32)
            .unwrap_or(1);

        if let Some(task_type) = task_type.as_deref() {
            if !ALLOWED_TASK_TYPES.contains(&task_type) {
                errors.push(CropSetupProposalValidationError::new(
                    format!("{prefix}.task_type"),
                    "must be field_work, basal_fertilization, or topdress_fertilization",
                ));
            }
        }

        if let Some(ref_key) = agricultural_task_ref.as_deref() {
            if !task_refs.contains(ref_key) {
                errors.push(CropSetupProposalValidationError::new(
                    format!("{prefix}.agricultural_task_ref"),
                    "must reference an agricultural_tasks.ref in the proposal",
                ));
            }
        }

        if let Some(stage_order) = stage_order {
            if !proposal_stage_orders.contains(&stage_order) {
                errors.push(CropSetupProposalValidationError::new(
                    format!("{prefix}.stage_order"),
                    "must match a stages[].order in the proposal",
                ));
            }
        }

        if let (Some(agricultural_task_ref), Some(stage_order), Some(gdd_trigger), Some(task_type)) =
            (agricultural_task_ref, stage_order, gdd_trigger, task_type)
        {
            let blueprint_key =
                format!("{agricultural_task_ref}:{stage_order}:{gdd_trigger}");
            if !seen_blueprint_keys.insert(blueprint_key) {
                errors.push(CropSetupProposalValidationError::new(
                    prefix.clone(),
                    "duplicate blueprint for the same task, stage, and gdd_trigger",
                ));
            }

            task_schedule_blueprints.push(CropSetupProposalBlueprintPlan {
                agricultural_task_ref,
                stage_order,
                stage_name: optional_string(obj, "stage_name"),
                gdd_trigger,
                task_type,
                priority,
            });
        }
    }

    if !errors.is_empty() {
        return Err(errors);
    }

    let plan = CropSetupProposalPlan {
        stages,
        agricultural_tasks,
        task_schedule_blueprints,
    };
    Ok((plan.clone(), plan_to_normalized_json(&plan)))
}

fn plan_to_normalized_json(plan: &CropSetupProposalPlan) -> Value {
    json!({
        "stages": plan.stages.iter().map(|stage| {
            json!({
                "name": stage.name,
                "order": stage.order,
                "temperature_requirement": stage.temperature_requirement,
                "thermal_requirement": stage.thermal_requirement,
                "sunshine_requirement": stage.sunshine_requirement,
                "nutrient_requirement": stage.nutrient_requirement,
            })
        }).collect::<Vec<_>>(),
        "agricultural_tasks": plan.agricultural_tasks.iter().map(|task| {
            json!({
                "ref": task.ref_key,
                "name": task.name,
                "description": task.description,
                "time_per_sqm": task.time_per_sqm,
                "skill_level": task.skill_level,
                "region": task.region,
                "task_type": task.task_type,
            })
        }).collect::<Vec<_>>(),
        "task_schedule_blueprints": plan.task_schedule_blueprints.iter().map(|bp| {
            json!({
                "agricultural_task_ref": bp.agricultural_task_ref,
                "stage_order": bp.stage_order,
                "stage_name": bp.stage_name,
                "gdd_trigger": bp.gdd_trigger,
                "task_type": bp.task_type,
                "priority": bp.priority,
            })
        }).collect::<Vec<_>>(),
    })
}

fn required_string(
    obj: &Map<String, Value>,
    key: &str,
    prefix: &str,
    errors: &mut Vec<CropSetupProposalValidationError>,
) -> Option<String> {
    match obj.get(key).and_then(|v| v.as_str()) {
        Some(value) if !value.trim().is_empty() => Some(value.to_string()),
        _ => {
            errors.push(CropSetupProposalValidationError::new(
                format!("{prefix}.{key}"),
                "is required",
            ));
            None
        }
    }
}

fn required_i32(
    obj: &Map<String, Value>,
    key: &str,
    prefix: &str,
    errors: &mut Vec<CropSetupProposalValidationError>,
) -> Option<i32> {
    match obj.get(key).and_then(parse_i32) {
        Some(value) => Some(value),
        None => {
            errors.push(CropSetupProposalValidationError::new(
                format!("{prefix}.{key}"),
                "is required",
            ));
            None
        }
    }
}

fn required_f64(
    obj: &Map<String, Value>,
    key: &str,
    prefix: &str,
    errors: &mut Vec<CropSetupProposalValidationError>,
) -> Option<f64> {
    match obj.get(key).and_then(parse_f64) {
        Some(value) if value.is_finite() && value >= 0.0 => Some(value),
        _ => {
            errors.push(CropSetupProposalValidationError::new(
                format!("{prefix}.{key}"),
                "is required and must be a non-negative number",
            ));
            None
        }
    }
}

fn optional_string(obj: &Map<String, Value>, key: &str) -> Option<String> {
    obj.get(key)
        .and_then(|v| v.as_str())
        .map(str::to_string)
}

fn optional_f64(obj: &Map<String, Value>, key: &str) -> Option<f64> {
    obj.get(key).and_then(parse_f64)
}

fn optional_object(obj: &Map<String, Value>, key: &str) -> Option<Value> {
    obj.get(key).cloned().filter(|v| !v.is_null())
}

fn parse_i32(value: &Value) -> Option<i32> {
    value
        .as_i64()
        .and_then(|v| i32::try_from(v).ok())
        .or_else(|| value.as_str().and_then(|s| s.parse().ok()))
}

fn parse_f64(value: &Value) -> Option<f64> {
    value
        .as_f64()
        .or_else(|| value.as_str().and_then(|s| s.parse().ok()))
}

fn parse_required_gdd(value: &Value) -> Option<f64> {
    value
        .get("required_gdd")
        .and_then(parse_f64)
        .filter(|v| v.is_finite())
}

#[cfg(test)]
mod policies_crop_setup_proposal_policy_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/crop/policies_crop_setup_proposal_policy_test.rs"
    ));
}
