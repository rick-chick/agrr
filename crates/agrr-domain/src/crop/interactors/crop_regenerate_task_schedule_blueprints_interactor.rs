//! Ruby: `CropTaskScheduleBlueprintRegenerationActiveRecordGateway` orchestration in domain.

use crate::crop::dtos::{
    CropBlueprintAiFailure, CropBlueprintRegenerateFailure, CropBlueprintRegenerateFailureReason,
    CropRegenerateTaskScheduleBlueprintsInput, CropTaskScheduleBlueprintPersistAttrs,
    MastersCropTaskScheduleBlueprint, HttpStatus,
};
use crate::crop::gateways::{
    CropAgrrRequirementGateway, CropGateway, CropMastersTaskScheduleBlueprintGateway,
    CropMastersTaskTemplateGateway,
};
use crate::crop::mappers::crop_task_template_agrr_mapper;
use crate::crop::mappers::task_schedule_blueprint_generator::TaskScheduleBlueprintGenerator;
use crate::crop::ports::{
    CropFertilizePlanAiQueryGateway, CropRegenerateTaskScheduleBlueprintsInputPort,
    CropScheduleAiQueryGateway,
};
use crate::shared::exceptions::RecordNotFoundError;

pub struct CropRegenerateTaskScheduleBlueprintsInteractor<'a, CG, TG, BG, AG, SG, FG> {
    crop_gateway: &'a CG,
    template_gateway: &'a TG,
    blueprint_gateway: &'a BG,
    agrr_requirement_gateway: &'a AG,
    schedule_gateway: &'a SG,
    fertilize_gateway: &'a FG,
}

impl<'a, CG, TG, BG, AG, SG, FG> CropRegenerateTaskScheduleBlueprintsInteractor<'a, CG, TG, BG, AG, SG, FG>
where
    CG: CropGateway,
    TG: CropMastersTaskTemplateGateway,
    BG: CropMastersTaskScheduleBlueprintGateway,
    AG: CropAgrrRequirementGateway,
    SG: CropScheduleAiQueryGateway,
    FG: CropFertilizePlanAiQueryGateway,
{
    pub fn new(
        crop_gateway: &'a CG,
        template_gateway: &'a TG,
        blueprint_gateway: &'a BG,
        agrr_requirement_gateway: &'a AG,
        schedule_gateway: &'a SG,
        fertilize_gateway: &'a FG,
    ) -> Self {
        Self {
            crop_gateway,
            template_gateway,
            blueprint_gateway,
            agrr_requirement_gateway,
            schedule_gateway,
            fertilize_gateway,
        }
    }

    fn regenerate_for_crop(
        &self,
        crop_id: i64,
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, CropBlueprintRegenerateFailure> {
        let crop = self.crop_gateway.find_by_id(crop_id).map_err(|e| {
            if e.downcast_ref::<RecordNotFoundError>().is_some() {
                CropBlueprintRegenerateFailure::new(
                    CropBlueprintRegenerateFailureReason::CropNotFound,
                    "Crop not found",
                )
            } else {
                CropBlueprintRegenerateFailure::new(
                    CropBlueprintRegenerateFailureReason::AiExecutionFailed,
                    e.to_string(),
                )
            }
        })?;

        let templates = self
            .template_gateway
            .list_by_crop_id(crop_id)
            .map_err(|e| {
                CropBlueprintRegenerateFailure::new(
                    CropBlueprintRegenerateFailureReason::AiExecutionFailed,
                    e.to_string(),
                )
            })?;

        if templates.is_empty() {
            return Err(CropBlueprintRegenerateFailure::new(
                CropBlueprintRegenerateFailureReason::MissingTaskTemplates,
                "作業テンプレート生成には作物の作業テンプレート登録が必要です",
            ));
        }

        let crop_requirement = self
            .agrr_requirement_gateway
            .build_for_crop_id(crop_id)
            .map_err(|e| {
                CropBlueprintRegenerateFailure::new(
                    CropBlueprintRegenerateFailureReason::AiExecutionFailed,
                    e.to_string(),
                )
            })?
            .ok_or_else(|| {
                CropBlueprintRegenerateFailure::new(
                    CropBlueprintRegenerateFailureReason::MissingAgrrRequirement,
                    "crop has no growth stages for agrr requirement",
                )
            })?;

        let stage_requirements = crop_requirement
            .get("stage_requirements")
            .cloned()
            .ok_or_else(|| {
                CropBlueprintRegenerateFailure::new(
                    CropBlueprintRegenerateFailureReason::MissingAgrrRequirement,
                    "stage_requirements missing from agrr requirement",
                )
            })?;

        let variety = crop
            .variety
            .as_deref()
            .filter(|v| !v.is_empty())
            .unwrap_or("general");

        let agricultural_tasks =
            serde_json::Value::Array(crop_task_template_agrr_mapper::to_agrr_format_array(
                &templates,
            ));

        let schedule_response = self
            .schedule_gateway
            .generate_schedule(&crop.name, variety, &stage_requirements, &agricultural_tasks)
            .map_err(map_ai_failure)?;

        let fertilize_response = self
            .fertilize_gateway
            .fetch_fertilize_plan(&crop_requirement, true, 2)
            .map_err(map_ai_failure)?;

        let generator = TaskScheduleBlueprintGenerator::new(crop_id, &templates);
        let blueprint_rows =
            generator.build_from_responses(&schedule_response, &fertilize_response);

        if blueprint_rows.is_empty() {
            return Err(CropBlueprintRegenerateFailure::new(
                CropBlueprintRegenerateFailureReason::BlueprintRegenerationFromAgrrFailed,
                "AGRRの応答から作業テンプレートを生成できませんでした",
            ));
        }

        let persist_attrs: Vec<CropTaskScheduleBlueprintPersistAttrs> = blueprint_rows
            .into_iter()
            .map(CropTaskScheduleBlueprintPersistAttrs::from)
            .collect();

        self.blueprint_gateway
            .replace_all_for_crop(crop_id, &persist_attrs)
            .map_err(|e| {
                CropBlueprintRegenerateFailure::new(
                    CropBlueprintRegenerateFailureReason::AiExecutionFailed,
                    e.to_string(),
                )
            })
    }

}

impl<'a, CG, TG, BG, AG, SG, FG> CropRegenerateTaskScheduleBlueprintsInputPort
    for CropRegenerateTaskScheduleBlueprintsInteractor<'a, CG, TG, BG, AG, SG, FG>
where
    CG: CropGateway,
    TG: CropMastersTaskTemplateGateway,
    BG: CropMastersTaskScheduleBlueprintGateway,
    AG: CropAgrrRequirementGateway,
    SG: CropScheduleAiQueryGateway,
    FG: CropFertilizePlanAiQueryGateway,
{
    fn call(
        &self,
        input: CropRegenerateTaskScheduleBlueprintsInput,
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, CropBlueprintRegenerateFailure> {
        self.regenerate_for_crop(input.crop_id)
    }
}

fn map_ai_failure(failure: CropBlueprintAiFailure) -> CropBlueprintRegenerateFailure {
    let reason = match failure.http_status {
        HttpStatus::ServiceUnavailable => CropBlueprintRegenerateFailureReason::AiUnavailable,
        _ => CropBlueprintRegenerateFailureReason::AiExecutionFailed,
    };
    CropBlueprintRegenerateFailure::new(reason, failure.message)
}

#[cfg(test)]
mod interactors_crop_regenerate_task_schedule_blueprints_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/crop/interactors_crop_regenerate_task_schedule_blueprints_interactor_test.rs"
    ));
}
