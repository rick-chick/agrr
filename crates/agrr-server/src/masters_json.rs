//! JSON shapes matching Rails `Api::V1::Masters::*` presenters.

use agrr_domain::crop::entities::{CropEntity, CropStageEntity};
use agrr_domain::farm::entities::{FarmEntity, FieldEntity as FarmFieldEntity};
use agrr_domain::field::entities::FieldEntity;
use serde_json::{json, Value};

pub fn farm_to_json(entity: &FarmEntity) -> Value {
    json!({
        "id": entity.id,
        "name": entity.name,
        "latitude": entity.latitude,
        "longitude": entity.longitude,
        "region": entity.region,
        "user_id": entity.user_id,
        "created_at": entity.created_at,
        "updated_at": entity.updated_at,
        "is_reference": entity.is_reference,
    })
}

pub fn farm_field_to_json(entity: &FarmFieldEntity) -> Value {
    json!({
        "id": entity.id,
        "name": entity.name,
        "area": entity.area,
        "daily_fixed_cost": entity.daily_fixed_cost,
        "region": entity.region,
        "farm_id": entity.farm_id,
        "user_id": entity.user_id,
        "created_at": entity.created_at,
        "updated_at": entity.updated_at,
    })
}

pub fn field_to_json(entity: &FieldEntity) -> Value {
    json!({
        "id": entity.id,
        "name": entity.name,
        "area": entity.area,
        "daily_fixed_cost": entity.daily_fixed_cost,
        "region": entity.region,
        "farm_id": entity.farm_id,
        "user_id": entity.user_id,
        "created_at": entity.created_at,
        "updated_at": entity.updated_at,
    })
}

pub fn crop_to_json(entity: &CropEntity, crop_stages: &[CropStageEntity]) -> Value {
    json!({
        "id": entity.id,
        "name": entity.name,
        "variety": entity.variety,
        "area_per_unit": entity.area_per_unit,
        "revenue_per_area": entity.revenue_per_area,
        "region": entity.region,
        "groups": entity.groups,
        "user_id": entity.user_id,
        "created_at": entity.created_at,
        "updated_at": entity.updated_at,
        "is_reference": entity.is_reference,
        "crop_stages": crop_stages.iter().map(crop_stage_to_json).collect::<Vec<_>>(),
    })
}

pub fn crop_stage_to_json(stage: &CropStageEntity) -> Value {
    let mut obj = json!({
        "id": stage.id,
        "crop_id": stage.crop_id,
        "name": stage.name,
        "order": stage.order,
    });
    if let Some(obj_map) = obj.as_object_mut() {
        if let Some(tr) = &stage.temperature_requirement {
            obj_map.insert(
                "temperature_requirement".into(),
                json!({
                    "id": tr.id,
                    "base_temperature": tr.base_temperature,
                    "optimal_min": tr.optimal_min,
                    "optimal_max": tr.optimal_max,
                    "low_stress_threshold": tr.low_stress_threshold,
                    "high_stress_threshold": tr.high_stress_threshold,
                    "frost_threshold": tr.frost_threshold,
                    "sterility_risk_threshold": tr.sterility_risk_threshold,
                    "max_temperature": tr.max_temperature,
                }),
            );
        }
        if let Some(tr) = &stage.thermal_requirement {
            obj_map.insert(
                "thermal_requirement".into(),
                json!({ "id": tr.id, "required_gdd": tr.required_gdd }),
            );
        }
        if let Some(sr) = &stage.sunshine_requirement {
            obj_map.insert(
                "sunshine_requirement".into(),
                json!({
                    "id": sr.id,
                    "minimum_sunshine_hours": sr.minimum_sunshine_hours,
                    "target_sunshine_hours": sr.target_sunshine_hours,
                }),
            );
        }
        if let Some(nr) = &stage.nutrient_requirement {
            obj_map.insert(
                "nutrient_requirement".into(),
                json!({
                    "id": nr.id,
                    "daily_uptake_n": nr.daily_uptake_n,
                    "daily_uptake_p": nr.daily_uptake_p,
                    "daily_uptake_k": nr.daily_uptake_k,
                    "region": nr.region,
                }),
            );
        }
    }
    obj
}

pub fn farm_destroy_undo_json(
    undo: &Value,
    farm_name: &str,
    toast_key: &str,
) -> Value {
    let undo_token = undo.get("undo_token").and_then(|v| v.as_str()).unwrap_or("");
    let undo_deadline = undo
        .get("expires_at")
        .and_then(|v| v.as_str())
        .unwrap_or("");
    json!({
        "undo": {
            "undo_token": undo_token,
            "undo_path": format!("/undo_deletion?undo_token={undo_token}"),
            "toast_message": format!("{toast_key}:{farm_name}"),
            "undo_deadline": undo_deadline,
            "auto_hide_after": 5000
        }
    })
}

pub fn crop_destroy_undo_json(undo: &Value, crop_name: &str) -> Value {
    let undo_token = undo.get("undo_token").and_then(|v| v.as_str()).unwrap_or("");
    let undo_deadline = undo
        .get("expires_at")
        .and_then(|v| v.as_str())
        .unwrap_or("");
    json!({
        "undo": {
            "undo_token": undo_token,
            "undo_path": format!("/undo_deletion?undo_token={undo_token}"),
            "toast_message": format!("flash.crops.deleted:{crop_name}"),
            "undo_deadline": undo_deadline,
            "auto_hide_after": 5000
        }
    })
}
