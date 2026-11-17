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
            organization_id: None,
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
            "undo_path": "/undo_deletion",
            "toast_message": toast_message,
            "undo_deadline": undo_deadline,
            "auto_hide_after": 5000
        }
    })
}

#[cfg(test)]
mod crop_json_tests {
    use super::*;
    use agrr_domain::crop::entities::{
        CropEntity, CropStageEntity, NutrientRequirementEntity, SunshineRequirementEntity,
        TemperatureRequirementEntity, ThermalRequirementEntity,
    };
    use rust_decimal::Decimal;

    #[test]
    fn crop_to_json_embeds_stage_list() {
        let crop = CropEntity {
            id: 1,
            user_id: Some(9),
            organization_id: None,
            name: "Tomato".into(),
            variety: Some("Momotaro".into()),
            is_reference: false,
            area_per_unit: Some(0.25),
            revenue_per_area: Some(1200.0),
            region: Some("jp".into()),
            groups: vec!["solanaceae".into()],
            cultivation_method: None,
            created_at: None,
            updated_at: None,
        };
        let stage = CropStageEntity {
            id: 2,
            crop_id: 1,
            name: "seedling".into(),
            order: 1,
            temperature_requirement: None,
            thermal_requirement: None,
            sunshine_requirement: None,
            nutrient_requirement: None,
            created_at: None,
            updated_at: None,
        };
        let json = crop_to_json(&crop, &[stage]);
        assert_eq!(json["name"], "Tomato");
        assert_eq!(json["groups"][0], "solanaceae");
        assert_eq!(json["crop_stages"].as_array().unwrap().len(), 1);
        assert_eq!(json["crop_stages"][0]["name"], "seedling");
    }

    #[test]
    fn crop_stage_to_json_omits_absent_requirements() {
        let stage = CropStageEntity {
            id: 1,
            crop_id: 2,
            name: "flowering".into(),
            order: 3,
            temperature_requirement: None,
            thermal_requirement: None,
            sunshine_requirement: None,
            nutrient_requirement: None,
            created_at: None,
            updated_at: None,
        };
        let json = crop_stage_to_json(&stage);
        assert!(!json.as_object().unwrap().contains_key("temperature_requirement"));
        assert!(!json.as_object().unwrap().contains_key("thermal_requirement"));
    }

    #[test]
    fn crop_stage_to_json_includes_nested_requirement_objects() {
        let stage = CropStageEntity {
            id: 5,
            crop_id: 6,
            name: "fruiting".into(),
            order: 2,
            temperature_requirement: Some(TemperatureRequirementEntity {
                id: 10,
                crop_stage_id: 5,
                base_temperature: Some(Decimal::new(100, 1)),
                optimal_min: None,
                optimal_max: None,
                low_stress_threshold: None,
                high_stress_threshold: None,
                frost_threshold: None,
                sterility_risk_threshold: None,
                max_temperature: None,
            }),
            thermal_requirement: Some(ThermalRequirementEntity {
                id: 11,
                crop_stage_id: 5,
                required_gdd: Some(Decimal::new(800, 0)),
            }),
            sunshine_requirement: Some(SunshineRequirementEntity {
                id: 12,
                crop_stage_id: 5,
                minimum_sunshine_hours: Some(Decimal::new(6, 0)),
                target_sunshine_hours: None,
            }),
            nutrient_requirement: Some(NutrientRequirementEntity {
                id: 13,
                crop_stage_id: 5,
                daily_uptake_n: None,
                daily_uptake_p: None,
                daily_uptake_k: None,
                region: Some("jp".into()),
            }),
            created_at: None,
            updated_at: None,
        };
        let json = crop_stage_to_json(&stage);
        assert_eq!(
            json["temperature_requirement"]["base_temperature"],
            "10.0"
        );
        assert_eq!(json["thermal_requirement"]["required_gdd"], "800");
        assert_eq!(json["sunshine_requirement"]["minimum_sunshine_hours"], "6");
        assert_eq!(json["nutrient_requirement"]["region"], "jp");
    }
}

#[cfg(test)]
mod masters_destroy_undo_json_tests {
    use super::*;

    #[test]
    fn masters_destroy_undo_json_wires_token_deadline_and_toast() {
        let undo = json!({
            "undo_token": "abc123",
            "expires_at": "2026-12-31T00:00:00Z",
        });
        let json = masters_destroy_undo_json(&undo, "Farm deleted");
        assert_eq!(json["undo"]["undo_token"], "abc123");
        assert_eq!(json["undo"]["undo_deadline"], "2026-12-31T00:00:00Z");
        assert_eq!(json["undo"]["toast_message"], "Farm deleted");
        assert_eq!(json["undo"]["undo_path"], "/undo_deletion");
        assert_eq!(json["undo"]["auto_hide_after"], 5000);
    }

    #[test]
    fn masters_destroy_undo_json_defaults_missing_undo_fields_to_empty_strings() {
        let json = masters_destroy_undo_json(&json!({}), "Crop deleted");
        assert_eq!(json["undo"]["undo_token"], "");
        assert_eq!(json["undo"]["undo_deadline"], "");
    }
}

#[cfg(test)]
mod field_json_tests {
    use super::*;
    use agrr_domain::farm::entities::FieldEntity as FarmFieldEntity;
    use agrr_domain::field::entities::FieldEntity;

    #[test]
    fn farm_field_to_json_maps_farm_nested_field_shape() {
        let entity = FarmFieldEntity {
            id: 3,
            name: "North bed".into(),
            area: Some(1.5),
            daily_fixed_cost: Some(200.0),
            region: Some("jp".into()),
            farm_id: 9,
            user_id: Some(4),
            created_at: Some("2026-01-01T00:00:00Z".into()),
            updated_at: Some("2026-01-02T00:00:00Z".into()),
        };
        let json = farm_field_to_json(&entity);
        assert_eq!(json["id"], 3);
        assert_eq!(json["name"], "North bed");
        assert_eq!(json["farm_id"], 9);
        assert_eq!(json["area"], 1.5);
        assert_eq!(json["daily_fixed_cost"], 200.0);
        assert_eq!(json["region"], "jp");
        assert_eq!(json["user_id"], 4);
    }

    #[test]
    fn field_to_json_maps_masters_fields_index_shape_and_omits_description() {
        let entity = FieldEntity {
            id: 11,
            farm_id: 2,
            user_id: Some(7),
            name: "East".into(),
            description: Some("internal note".into()),
            created_at: Some("2026-02-01T00:00:00Z".into()),
            updated_at: None,
            area: Some(0.75),
            daily_fixed_cost: None,
            region: Some("jp".into()),
        };
        let json = field_to_json(&entity);
        assert_eq!(json["id"], 11);
        assert_eq!(json["name"], "East");
        assert_eq!(json["farm_id"], 2);
        assert_eq!(json["user_id"], 7);
        assert_eq!(json["area"], 0.75);
        assert!(json.get("description").is_none());
        assert!(json["daily_fixed_cost"].is_null());
        assert!(json["updated_at"].is_null());
    }
}

