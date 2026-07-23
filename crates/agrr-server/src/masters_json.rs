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
        "weather_data_status": entity.weather_data_status,
        "weather_data_progress": entity.weather_data_progress(),
        "weather_data_fetched_years": entity.weather_data_fetched_years,
        "weather_data_total_years": entity.weather_data_total_years,
    })
}

#[cfg(test)]
mod farm_to_json_tests {
    use super::*;
    use agrr_domain::farm::entities::FarmEntity;

    fn sample_farm(status: Option<&str>, fetched: Option<i32>, total: Option<i32>) -> FarmEntity {
        FarmEntity {
            id: 1,
            name: "Test Farm".into(),
            latitude: Some(35.0),
            longitude: Some(139.0),
            region: Some("jp".into()),
            user_id: Some(10),
            created_at: None,
            updated_at: None,
            is_reference: false,
            weather_data_status: status.map(str::to_string),
            weather_data_fetched_years: fetched,
            weather_data_total_years: total,
            weather_data_last_error: None,
            weather_location_id: None,
            last_broadcast_at: None,
        }
    }

    #[test]
    fn includes_weather_fields_for_completed_farm() {
        let json = farm_to_json(&sample_farm(Some("completed"), Some(5), Some(5)));
        assert_eq!("completed", json["weather_data_status"].as_str().unwrap());
        assert_eq!(100, json["weather_data_progress"].as_i64().unwrap());
        assert_eq!(5, json["weather_data_fetched_years"].as_i64().unwrap());
        assert_eq!(5, json["weather_data_total_years"].as_i64().unwrap());
    }

    #[test]
    fn includes_weather_fields_for_fetching_farm() {
        let json = farm_to_json(&sample_farm(Some("fetching"), Some(1), Some(5)));
        assert_eq!("fetching", json["weather_data_status"].as_str().unwrap());
        assert_eq!(20, json["weather_data_progress"].as_i64().unwrap());
    }
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

/// Nested undo payload for Angular masters delete (farm/crop share the same shape).
pub fn masters_destroy_undo_json(undo: &Value, toast_message: &str) -> Value {
    let undo_token = undo.get("undo_token").and_then(|v| v.as_str()).unwrap_or("");
    let undo_deadline = undo
        .get("expires_at")
        .and_then(|v| v.as_str())
        .unwrap_or("");
    json!({
        "undo": {
            "undo_token": undo_token,
            "undo_path": format!("/undo_deletion?undo_token={undo_token}"),
            "toast_message": toast_message,
            "undo_deadline": undo_deadline,
            "auto_hide_after": 5000
        }
    })
}

