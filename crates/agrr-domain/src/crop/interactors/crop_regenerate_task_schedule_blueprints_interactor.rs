//! Ruby: `CropTaskScheduleBlueprintRegenerationActiveRecordGateway` orchestration in domain.

use crate::agricultural_task::constants::schedule_item_types::{
    BASAL_FERTILIZATION, FIELD_WORK, TOPDRESS_FERTILIZATION,
};
use crate::agricultural_task::gateways::AgriculturalTaskGateway;
use crate::crop::dtos::{
    CropBlueprintAiFailure, CropBlueprintRegenerateFailure, CropBlueprintRegenerateFailureReason,
    CropRegenerateTaskScheduleBlueprintsInput, CropTaskScheduleBlueprintPersistAttrs,
    MastersCropTaskScheduleBlueprint, HttpStatus,
};
use crate::crop::gateways::{
    CropAgrrRequirementGateway, CropGateway, CropMastersTaskScheduleBlueprintGateway,
};
use crate::crop::mappers::blueprint_attribute_lookup;
use crate::crop::mappers::crop_blueprint_agrr_mapper;
use crate::crop::mappers::task_schedule_blueprint_generator::TaskScheduleBlueprintGenerator;
use crate::crop::ports::{
    CropFertilizePlanAiQueryGateway, CropRegenerateTaskScheduleBlueprintsInputPort,
    CropScheduleAiQueryGateway,
};
use crate::shared::exceptions::RecordNotFoundError;

pub struct CropRegenerateTaskScheduleBlueprintsInteractor<'a, CG, BG, AG, AGW, SG, FG> {
    crop_gateway: &'a CG,
    blueprint_gateway: &'a BG,
    agricultural_task_gateway: &'a AGW,
    agrr_requirement_gateway: &'a AG,
    schedule_gateway: &'a SG,
    fertilize_gateway: &'a FG,
}

impl<'a, CG, BG, AG, AGW, SG, FG>
    CropRegenerateTaskScheduleBlueprintsInteractor<'a, CG, BG, AG, AGW, SG, FG>
where
    CG: CropGateway,
    BG: CropMastersTaskScheduleBlueprintGateway,
    AGW: AgriculturalTaskGateway,
    AG: CropAgrrRequirementGateway,
    SG: CropScheduleAiQueryGateway,
    FG: CropFertilizePlanAiQueryGateway,
{
    pub fn new(
        crop_gateway: &'a CG,
        blueprint_gateway: &'a BG,
        agricultural_task_gateway: &'a AGW,
        agrr_requirement_gateway: &'a AG,
        schedule_gateway: &'a SG,
        fertilize_gateway: &'a FG,
    ) -> Self {
        Self {
            crop_gateway,
            blueprint_gateway,
            agricultural_task_gateway,
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

        let blueprints = self
            .blueprint_gateway
            .list_by_crop_id(crop_id)
            .map_err(|e| {
                CropBlueprintRegenerateFailure::new(
                    CropBlueprintRegenerateFailureReason::AiExecutionFailed,
                    e.to_string(),
                )
            })?;

        if blueprints.is_empty() {
            return Err(CropBlueprintRegenerateFailure::new(
                CropBlueprintRegenerateFailureReason::MissingBlueprints,
                "作業予定ブループリントが1件以上必要です",
            ));
        }

        let agricultural_tasks = {
            let mut tasks = Vec::new();
            let mut seen = std::collections::HashSet::new();
            for blueprint in &blueprints {
                let Some(task_id) = blueprint.agricultural_task_id else {
                    continue;
                };
                if !seen.insert(task_id) {
                    continue;
                }
                tasks.push(
                    self.agricultural_task_gateway
                        .find_by_id(task_id)
                        .map_err(|e| {
                            CropBlueprintRegenerateFailure::new(
                                CropBlueprintRegenerateFailureReason::AiExecutionFailed,
                                e.to_string(),
                            )
                        })?,
                );
            }
            tasks
        };

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

        let field_work_blueprints: Vec<_> = blueprints
            .iter()
            .filter(|row| row.task_type == FIELD_WORK)
            .cloned()
            .collect();

        let agricultural_tasks_json = serde_json::Value::Array(
            crop_blueprint_agrr_mapper::to_agrr_format_array(
                &field_work_blueprints,
                &agricultural_tasks,
            ),
        );

        if agricultural_tasks_json.as_array().is_some_and(|rows| rows.is_empty()) {
            return Err(CropBlueprintRegenerateFailure::new(
                CropBlueprintRegenerateFailureReason::MissingBlueprints,
                "field-work blueprints with registered agricultural tasks are required",
            ));
        }

        let schedule_response = self
            .schedule_gateway
            .generate_schedule(
                &crop.name,
                variety,
                &stage_requirements,
                &agricultural_tasks_json,
            )
            .map_err(map_ai_failure)?;

        let fertilize_response = self
            .fertilize_gateway
            .fetch_fertilize_plan(&crop_requirement, true, 2)
            .map_err(map_ai_failure)?;

        let attribute_by_blueprint = blueprint_attribute_lookup::build_attribute_lookup_by_blueprint_id(
            &blueprints,
            &agricultural_tasks,
        );
        let attribute_by_agricultural_task =
            blueprint_attribute_lookup::build_attribute_lookup_by_agricultural_task_id(
                &blueprints,
                &agricultural_tasks,
            );
        let agricultural_task_id_by_blueprint: std::collections::HashMap<i64, i64> = blueprints
            .iter()
            .filter_map(|blueprint| {
                blueprint
                    .agricultural_task_id
                    .map(|task_id| (blueprint.id, task_id))
            })
            .collect();
        let generator = TaskScheduleBlueprintGenerator::new(
            crop_id,
            attribute_by_blueprint,
            attribute_by_agricultural_task,
            agricultural_task_id_by_blueprint,
        );
        let blueprint_rows =
            generator.build_from_responses(&schedule_response, &fertilize_response);

        if blueprint_rows.is_empty() {
            return Err(CropBlueprintRegenerateFailure::new(
                CropBlueprintRegenerateFailureReason::BlueprintRegenerationFromAgrrFailed,
                "AGRRの応答から作業予定ブループリントを生成できませんでした",
            ));
        }

        let persist_attrs: Vec<CropTaskScheduleBlueprintPersistAttrs> = blueprint_rows
            .into_iter()
            .map(CropTaskScheduleBlueprintPersistAttrs::from)
            .collect();

        self.apply_regenerated_blueprints(crop_id, &persist_attrs)
    }

    fn apply_regenerated_blueprints(
        &self,
        crop_id: i64,
        records: &[CropTaskScheduleBlueprintPersistAttrs],
    ) -> Result<Vec<MastersCropTaskScheduleBlueprint>, CropBlueprintRegenerateFailure> {
        self.blueprint_gateway
            .delete_fertilize_blueprints_for_crop(crop_id)
            .map_err(map_gateway_failure)?;

        for rec in records {
            if rec.task_type == BASAL_FERTILIZATION || rec.task_type == TOPDRESS_FERTILIZATION {
                self.blueprint_gateway
                    .create(rec.clone())
                    .map_err(map_gateway_failure)?;
                continue;
            }

            let Some(blueprint_id) = rec.blueprint_id else {
                continue;
            };

            self.blueprint_gateway
                .update_regenerated_field_work(crop_id, blueprint_id, rec)
                .map_err(map_gateway_failure)?;
        }

        self.blueprint_gateway
            .list_by_crop_id(crop_id)
            .map_err(map_gateway_failure)
    }
}

impl<'a, CG, BG, AG, AGW, SG, FG> CropRegenerateTaskScheduleBlueprintsInputPort
    for CropRegenerateTaskScheduleBlueprintsInteractor<'a, CG, BG, AG, AGW, SG, FG>
where
    CG: CropGateway,
    BG: CropMastersTaskScheduleBlueprintGateway,
    AGW: AgriculturalTaskGateway,
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

fn map_gateway_failure(
    e: Box<dyn std::error::Error + Send + Sync>,
) -> CropBlueprintRegenerateFailure {
    CropBlueprintRegenerateFailure::new(
        CropBlueprintRegenerateFailureReason::AiExecutionFailed,
        e.to_string(),
    )
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
