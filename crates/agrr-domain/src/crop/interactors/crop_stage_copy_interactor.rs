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
                        json!({ "required_gdd": ref_thermal.required_gdd }),
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
mod tests {
    use super::*;
    use crate::crop::entities::{
        TemperatureRequirementEntity, ThermalRequirementEntity,
    };
    use std::sync::atomic::{AtomicBool, Ordering};

    static CREATE_TEMP_CALLED: AtomicBool = AtomicBool::new(false);

    struct CopyGw;
    impl CropGateway for CopyGw {

        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<crate::crop::entities::CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(crate::crop::entities::CropEntity::new(1, "c", None, false).unwrap())
        }
    
    fn list_by_crop_id(
            &self,
            crop_id: i64,
        ) -> Result<Vec<CropStageEntity>, Box<dyn std::error::Error + Send + Sync>> {
            if crop_id == 1 {
                let mut temp =
                    TemperatureRequirementEntity::new(1, 10).unwrap();
                temp.base_temperature = Some(Decimal::from(10));
                temp.optimal_min = Some(Decimal::from(15));
                temp.optimal_max = Some(Decimal::from(25));
                temp.low_stress_threshold = Some(Decimal::from(5));
                temp.high_stress_threshold = Some(Decimal::from(30));
                temp.frost_threshold = Some(Decimal::from(0));
                temp.max_temperature = Some(Decimal::from(35));
                let mut stage = CropStageEntity::new(10, 1, "Vegetative", 1).unwrap();
                stage.temperature_requirement = Some(temp);
                Ok(vec![stage])
            } else {
                Ok(vec![])
            }
        }
        fn create_crop_stage(
            &self,
            input: CropStageCreateInput,
        ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(CropStageEntity::new(20, input.crop_id, "Vegetative", 1).unwrap())
        }
        fn create_temperature_requirement(
            &self,
            _: i64,
            _: TemperatureRequirementUpdateInput,
        ) -> Result<TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
            CREATE_TEMP_CALLED.store(true, Ordering::SeqCst);
            Ok(TemperatureRequirementEntity::new(2, 20).unwrap())
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<
            Vec<crate::crop::entities::CropEntity>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn find_crop_show_detail(
            &self,
            _: i64,
        ) -> Result<crate::crop::dtos::CropShowDetail, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_crop_record_with_stages(
            &self,
            _: i64,
        ) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn count_user_owned_non_reference_crops(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &crate::shared::user::User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &crate::shared::user::User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<crate::crop::entities::CropEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<crate::crop::dtos::CropDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &crate::shared::user::User,
            _: i64,
            _: i64,
            _: &str,
        ) -> Result<
            crate::crop::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_crop_stage(
            &self,
            _: i64,
            _: crate::crop::dtos::CropStageUpdateInput,
        ) -> Result<CropStageEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn delete_crop_stage(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_thermal_requirement(
            &self,
            _: i64,
            _: ThermalRequirementUpdateInput,
        ) -> Result<ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_thermal_requirement(
            &self,
            _: i64,
            _: ThermalRequirementUpdateInput,
        ) -> Result<ThermalRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn delete_thermal_requirement(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_temperature_requirement(
            &self,
            _: i64,
            _: TemperatureRequirementUpdateInput,
        ) -> Result<TemperatureRequirementEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn delete_temperature_requirement(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_sunshine_requirement(
            &self,
            _: i64,
            _: SunshineRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::SunshineRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_sunshine_requirement(
            &self,
            _: i64,
            _: SunshineRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::SunshineRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_sunshine_requirement(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_nutrient_requirement(
            &self,
            _: i64,
            _: NutrientRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::NutrientRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn update_nutrient_requirement(
            &self,
            _: i64,
            _: NutrientRequirementUpdateInput,
        ) -> Result<
            crate::crop::entities::NutrientRequirementEntity,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_nutrient_requirement(
            &self,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn masters_crop_agricultural_task_templates_index_rows(
            &self,
            _: i64,
        ) -> Result<Vec<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_masters_crop_task_template_for_api(
            &self,
            _: i64,
            _: i64,
            _: serde_json::Value,
        ) -> Result<
            crate::crop::gateways::UpdateMastersCropTaskTemplateOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn delete_masters_crop_task_template(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    // Ruby: test "creates missing stage and requirements on target crop"
    #[test]
    fn creates_missing_stage_and_requirements_on_target_crop() {
        CREATE_TEMP_CALLED.store(false, Ordering::SeqCst);
        let i = CropStageCopyInteractor::new(&CopyGw);
        i.call(CropStageCopyInput {
            reference_crop_id: 1,
            new_crop_id: 2,
        })
        .unwrap();
        assert!(CREATE_TEMP_CALLED.load(Ordering::SeqCst));
    }
}
