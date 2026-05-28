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
        plan_predicted_weather_present: source
            .predicted_weather_data
            .as_ref()
            .is_some_and(crate::shared::validation::present),
        prediction_target_end_date: source.prediction_target_end_date,
        calculated_planning_end_date: source.calculated_planning_end_date,
        predicted_weather_data: source.predicted_weather_data.clone(),
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
mod tests {
    use super::*;
    use time::macros::date;

    #[test]
    fn maps_crop_stages_into_context() {
        let source = FieldCultivationClimateSourceSnapshot {
            field_cultivation_id: 1,
            field_name: "A".into(),
            crop_name: "Tomato".into(),
            start_date: Some(date!(2026 - 03 - 01)),
            completion_date: Some(date!(2026 - 03 - 10)),
            farm_id: 10,
            farm_name: "Farm".into(),
            farm_latitude: 35.0,
            farm_longitude: 139.0,
            weather_location_id: Some(1),
            weather_location_timezone: None,
            plan_id: 5,
            plan_type_public: false,
            prediction_target_end_date: None,
            calculated_planning_end_date: None,
            predicted_weather_data: None,
            plan_crop_crop_id: Some(2),
        };
        let crop = ClimateCropEntity {
            id: 2,
            is_reference: false,
            user_id: Some(1),
            crop_stages: vec![ClimateCropStage {
                name: "S1".into(),
                order: 1,
                temperature_requirement: Some(ClimateTemperatureRequirement {
                    base_temperature: 10.0,
                    optimal_min: Some(15.0),
                    optimal_max: Some(25.0),
                    low_stress_threshold: None,
                    high_stress_threshold: None,
                }),
                thermal_requirement: Some(
                    crate::field_cultivation::dtos::ClimateThermalRequirement {
                        required_gdd: 100.0,
                    },
                ),
            }],
        };
        let ctx = to_context_snapshot(&source, &crop);
        assert_eq!(ctx.crop_id, 2);
        assert_eq!(ctx.stages.len(), 1);
    }
}
