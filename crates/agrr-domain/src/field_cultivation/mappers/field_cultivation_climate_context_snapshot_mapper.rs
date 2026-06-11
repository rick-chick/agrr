use serde_json::{json, Value};

use crate::field_cultivation::dtos::{
    ClimateCropEntity, ClimateCropStage, ClimateTemperatureRequirement,
    FieldCultivationClimateContextSnapshot, FieldCultivationClimateSourceSnapshot,
};

pub fn to_context_snapshot(
    source: &FieldCultivationClimateSourceSnapshot,
    crop: &ClimateCropEntity,
) -> FieldCultivationClimateContextSnapshot {
    let stages = build_stage_requirements(crop);
    let first_stage = crop
        .crop_stages
        .iter()
        .min_by_key(|st| st.order);
    let temp_req = first_stage.and_then(|st| st.temperature_requirement.as_ref());
    let base_temperature = temp_req.map(|t| t.base_temperature).unwrap_or(10.0);

    FieldCultivationClimateContextSnapshot {
        field_cultivation_id: source.field_cultivation_id,
        field_name: source.field_name.clone(),
        crop_name: source.crop_name.clone(),
        start_date: source.start_date.expect("precondition ensures start_date"),
        completion_date: source
            .completion_date
            .expect("precondition ensures completion_date"),
        farm_id: source.farm_id,
        farm_name: source.farm_name.clone(),
        farm_latitude: source.farm_latitude,
        farm_longitude: source.farm_longitude,
        plan_id: source.plan_id,
        plan_type_public: source.plan_type_public,
        plan_predicted_weather_present: source.plan_metadata.is_some(),
        prediction_target_end_date: source.prediction_target_end_date,
        calculated_planning_end_date: source.calculated_planning_end_date,
        plan_metadata: source.plan_metadata.clone(),
        crop_id: crop.id,
        base_temperature,
        optimal_temperature_range: temp_req.map(build_optimal_temperature_range),
        stages,
    }
}

fn build_optimal_temperature_range(temp_req: &ClimateTemperatureRequirement) -> Value {
    json!({
        "min": temp_req.optimal_min,
        "max": temp_req.optimal_max,
        "low_stress": temp_req.low_stress_threshold,
        "high_stress": temp_req.high_stress_threshold,
    })
}

fn build_stage_requirements(crop: &ClimateCropEntity) -> Vec<Value> {
    if crop.crop_stages.is_empty() {
        return vec![];
    }

    let mut sorted: Vec<&ClimateCropStage> = crop.crop_stages.iter().collect();
    sorted.sort_by_key(|st| st.order);

    let mut cumulative_gdd = 0.0;
    let mut out = Vec::new();

    for crop_stage in sorted {
        let Some(temp_req) = crop_stage.temperature_requirement.as_ref() else {
            continue;
        };
        let Some(thermal_req) = crop_stage.thermal_requirement.as_ref() else {
            continue;
        };

        cumulative_gdd += thermal_req.required_gdd;
        out.push(json!({
            "name": crop_stage.name,
            "order": crop_stage.order,
            "gdd_required": thermal_req.required_gdd,
            "cumulative_gdd_required": (cumulative_gdd * 100.0).round() / 100.0,
            "optimal_temperature_min": temp_req.optimal_min,
            "optimal_temperature_max": temp_req.optimal_max,
            "low_stress_threshold": temp_req.low_stress_threshold,
            "high_stress_threshold": temp_req.high_stress_threshold,
        }));
    }

    out
}

#[cfg(test)]
mod mappers_field_cultivation_climate_context_snapshot_mapper_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field_cultivation/mappers_field_cultivation_climate_context_snapshot_mapper_test.rs"));
}
