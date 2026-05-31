use serde_json::{json, Value};

use crate::field_cultivation::dtos::ClimateCropEntity;

/// Builds agrr crop-requirement JSON (Ruby `CropAgrrRequirementMapper` / `build_crop_agrr_requirement`).
pub fn from_climate_crop_entity(entity: &ClimateCropEntity) -> Value {
    let mut stage_requirements = Vec::new();

    for stage in &entity.crop_stages {
        let Some(temp) = stage.temperature_requirement.as_ref() else {
            continue;
        };
        let Some(thermal) = stage.thermal_requirement.as_ref() else {
            continue;
        };

        stage_requirements.push(json!({
            "stage": {
                "name": stage.name,
                "order": stage.order
            },
            "temperature": {
                "base_temperature": temp.base_temperature,
                "optimal_min": temp.optimal_min,
                "optimal_max": temp.optimal_max,
                "low_stress_threshold": temp.low_stress_threshold,
                "high_stress_threshold": temp.high_stress_threshold,
                "frost_threshold": temp.frost_threshold,
                "max_temperature": temp.max_temperature.unwrap_or(50.0)
            },
            "thermal": {
                "required_gdd": thermal.required_gdd
            }
        }));
    }

    let revenue = entity.revenue_per_area.unwrap_or(5000.0);
    json!({
        "crop": {
            "crop_id": entity.id.to_string(),
            "name": entity.name,
            "variety": entity.variety.as_deref().unwrap_or("general"),
            "area_per_unit": entity.area_per_unit.unwrap_or(0.25),
            "revenue_per_area": revenue,
            "max_revenue": revenue * 100.0,
            "groups": entity.groups.clone()
        },
        "stage_requirements": stage_requirements
    })
}

#[cfg(test)]
mod mappers_climate_crop_agrr_requirement_mapper_test_inline {
    use super::*;
    use crate::field_cultivation::dtos::{
        ClimateCropEntity, ClimateCropStage, ClimateTemperatureRequirement, ClimateThermalRequirement,
    };
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/field_cultivation/mappers_climate_crop_agrr_requirement_mapper_test.rs"
    ));
}
