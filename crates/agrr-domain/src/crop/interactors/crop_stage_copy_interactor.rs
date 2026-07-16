//! Ruby: `Domain::Crop::Interactors::CropStageCopyInteractor`

use crate::crop::dtos::{
    CropStageCopyInput, CropStageCreateInput, NutrientRequirementUpdateInput,
    SunshineRequirementUpdateInput, TemperatureRequirementUpdateInput, ThermalRequirementUpdateInput,
};
use crate::crop::entities::{CropStageEntity, TemperatureRequirementEntity};
use crate::crop::gateways::CropGateway;
use rust_decimal::Decimal;
use serde_json::{json, Value};
use std::collections::HashMap;

pub struct CropStageCopyInteractor<'a, G> {
    crop_gateway: &'a G,
}

impl<'a, G> CropStageCopyInteractor<'a, G>
where
    G: CropGateway,
{
    pub fn new(crop_gateway: &'a G) -> Self {
        Self { crop_gateway }
    }

    pub fn call(
        &self,
        input: CropStageCopyInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.crop_gateway.find_by_id(input.reference_crop_id)?;
        self.crop_gateway.find_by_id(input.new_crop_id)?;

        let reference_stages = self.crop_gateway.list_by_crop_id(input.reference_crop_id)?;
        let target_stages = self.crop_gateway.list_by_crop_id(input.new_crop_id)?;
        let mut target_by_name: HashMap<String, CropStageEntity> = target_stages
            .into_iter()
            .map(|s| (s.name.clone(), s))
            .collect();

        for reference_stage in reference_stages {
            let mut target_stage = match target_by_name.remove(&reference_stage.name) {
                Some(stage) => stage,
                None => {
                    let created = self.crop_gateway.create_crop_stage(CropStageCreateInput::new(
                        input.new_crop_id,
                        json!({
                            "name": reference_stage.name,
                            "order": reference_stage.order,
                        }),
                    ))?;
                    target_by_name.insert(created.name.clone(), created.clone());
                    created
                }
            };

            self.copy_requirements(
                &reference_stage,
                &mut target_stage,
                input.new_crop_id,
            )?;
        }
        Ok(())
    }

    fn copy_requirements(
        &self,
        reference_stage: &CropStageEntity,
        target_stage: &mut CropStageEntity,
        new_crop_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(ref_temp) = &reference_stage.temperature_requirement {
            if target_stage.temperature_requirement.is_none() {
                let payload = temperature_payload(ref_temp);
                let created = self.crop_gateway.create_temperature_requirement(
                    target_stage.id,
                    TemperatureRequirementUpdateInput::new(
                        new_crop_id,
                        target_stage.id,
                        payload,
                    ),
                )?;
                target_stage.temperature_requirement = Some(created);
            }
        }

        if let Some(ref_thermal) = &reference_stage.thermal_requirement {
            if target_stage.thermal_requirement.is_none() {
                let created = self.crop_gateway.create_thermal_requirement(
                    target_stage.id,
                    ThermalRequirementUpdateInput::new(
                        new_crop_id,
                        target_stage.id,
                        json!({
                            "required_gdd": ref_thermal
                                .required_gdd
                                .as_ref()
                                .map(|d| d.to_string()),
                        }),
                    ),
                )?;
                target_stage.thermal_requirement = Some(created);
            }
        }

        if let Some(ref_sun) = &reference_stage.sunshine_requirement {
            if target_stage.sunshine_requirement.is_none() {
                let created = self.crop_gateway.create_sunshine_requirement(
                    target_stage.id,
                    SunshineRequirementUpdateInput::new(
                        new_crop_id,
                        target_stage.id,
                        json!({
                            "minimum_sunshine_hours": ref_sun.minimum_sunshine_hours,
                            "target_sunshine_hours": ref_sun.target_sunshine_hours,
                        }),
                    ),
                )?;
                target_stage.sunshine_requirement = Some(created);
            }
        }

        if let Some(ref_nutrient) = &reference_stage.nutrient_requirement {
            if target_stage.nutrient_requirement.is_none() {
                let _created = self.crop_gateway.create_nutrient_requirement(
                    target_stage.id,
                    NutrientRequirementUpdateInput::new(
                        new_crop_id,
                        target_stage.id,
                        json!({
                            "daily_uptake_n": ref_nutrient.daily_uptake_n,
                            "daily_uptake_p": ref_nutrient.daily_uptake_p,
                            "daily_uptake_k": ref_nutrient.daily_uptake_k,
                            "region": ref_nutrient.region,
                        }),
                    ),
                )?;
            }
        }

        Ok(())
    }
}

fn temperature_payload(ref_temp: &TemperatureRequirementEntity) -> Value {
    json!({
        "base_temperature": decimal_json(ref_temp.base_temperature),
        "optimal_min": decimal_json(ref_temp.optimal_min),
        "optimal_max": decimal_json(ref_temp.optimal_max),
        "low_stress_threshold": decimal_json(ref_temp.low_stress_threshold),
        "high_stress_threshold": decimal_json(ref_temp.high_stress_threshold),
        "frost_threshold": decimal_json(ref_temp.frost_threshold),
        "sterility_risk_threshold": decimal_json(ref_temp.sterility_risk_threshold),
        "max_temperature": decimal_json(ref_temp.max_temperature),
    })
}

fn decimal_json(value: Option<Decimal>) -> Value {
    value
        .map(|d| Value::String(d.to_string()))
        .unwrap_or(Value::Null)
}

#[cfg(test)]
mod interactors_crop_stage_copy_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_stage_copy_interactor_test.rs"));
}
