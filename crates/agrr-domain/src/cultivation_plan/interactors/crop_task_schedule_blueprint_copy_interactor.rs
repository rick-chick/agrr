//! Ruby: `Domain::CultivationPlan::Interactors::CropTaskScheduleBlueprintCopyInteractor`

use crate::cultivation_plan::calculators::planning_date_calculator::normalize_decimal;
use crate::cultivation_plan::dtos::{
    CropTaskScheduleBlueprintCopyInput, CropTaskScheduleBlueprintCreateAttrs,
};
use crate::cultivation_plan::gateways::CropTaskScheduleBlueprintGateway;
use crate::cultivation_plan::ports::UserAgriculturalTaskMappingPort;
use crate::shared::ports::LoggerPort;

pub struct CropTaskScheduleBlueprintCopyInteractor<'a, BG, TM, L> {
    blueprint_gateway: &'a BG,
    task_mapping_port: &'a TM,
    logger: &'a L,
}

impl<'a, BG, TM, L> CropTaskScheduleBlueprintCopyInteractor<'a, BG, TM, L>
where
    BG: CropTaskScheduleBlueprintGateway,
    TM: UserAgriculturalTaskMappingPort,
    L: LoggerPort,
{
    pub fn new(blueprint_gateway: &'a BG, task_mapping_port: &'a TM, logger: &'a L) -> Self {
        Self {
            blueprint_gateway,
            task_mapping_port,
            logger,
        }
    }

    pub fn call(
        &self,
        input: CropTaskScheduleBlueprintCopyInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if input.is_empty() {
            return Ok(());
        }

        for (reference_crop_id, user_crop_id) in &input.reference_crop_id_to_user_crop_id {
            self.copy_blueprints_for_pair(*reference_crop_id, *user_crop_id)?;
        }
        Ok(())
    }

    fn copy_blueprints_for_pair(
        &self,
        reference_crop_id: i64,
        user_crop_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let reference_blueprints = self.blueprint_gateway.list_by_crop_id(reference_crop_id)?;
        if reference_blueprints.is_empty() {
            return Ok(());
        }

        let create_records: Vec<CropTaskScheduleBlueprintCreateAttrs> = reference_blueprints
            .iter()
            .map(|blueprint| {
                let reference_task_id = blueprint
                    .source_agricultural_task_id
                    .or(blueprint.agricultural_task_id);
                let mapped_user_task_id = reference_task_id
                    .and_then(|id| self.task_mapping_port.user_task_id_for(Some(id)));

                CropTaskScheduleBlueprintCreateAttrs {
                    crop_id: user_crop_id,
                    agricultural_task_id: mapped_user_task_id,
                    source_agricultural_task_id: reference_task_id,
                    stage_order: blueprint.stage_order,
                    stage_name: blueprint.stage_name.clone(),
                    gdd_trigger: normalize_decimal(blueprint.gdd_trigger),
                    gdd_tolerance: normalize_decimal(blueprint.gdd_tolerance),
                    task_type: blueprint.task_type.clone(),
                    source: blueprint.source.clone(),
                    priority: blueprint.priority,
                    amount: normalize_decimal(blueprint.amount),
                    amount_unit: blueprint.amount_unit.clone(),
                    description: blueprint.description.clone(),
                    weather_dependency: blueprint.weather_dependency.clone(),
                    time_per_sqm: normalize_decimal(blueprint.time_per_sqm),
                }
            })
            .collect();

        self.blueprint_gateway.delete_by_crop_id(user_crop_id)?;
        self.blueprint_gateway.bulk_create(&create_records)?;
        let _ = &self.logger;
        Ok(())
    }
}
