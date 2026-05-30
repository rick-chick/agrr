//! Ruby: `Adapters::CultivationPlan::Sessions::PlanSaveSession#run_persist_steps`

use std::collections::HashMap;

use crate::crop::CropSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::crop::dtos::CropStageCopyInput;
use agrr_domain::crop::interactors::crop_stage_copy_interactor::CropStageCopyInteractor;
use agrr_domain::cultivation_plan::dtos::{
    CropTaskScheduleBlueprintCopyInput, PlanSaveEnsureUserAgriculturalTasksInput,
    PlanSaveEnsureUserCropsInput, PlanSaveEnsureUserFieldsInput,
    PlanSaveEnsureUserFertilizesInput, PlanSaveEnsureUserInteractionRulesInput,
    PlanSaveEnsureUserPesticidesInput, PlanSaveEnsureUserPestsInput,
    PublicPlanSaveFromSessionOutput, PublicPlanSaveSkippedItems, PublicPlanSaveWorkspace,
};
use agrr_domain::cultivation_plan::errors::PlanSaveRecordNotFoundError;
use agrr_domain::cultivation_plan::gateways::{
    PlanSaveFarmGateway, PlanSaveUserAgriculturalTaskGateway,
};
use agrr_domain::cultivation_plan::interactors::{
    CropTaskScheduleBlueprintCopyInteractor, PlanSaveEnsureUserAgriculturalTasksInteractor,
    PlanSaveEnsureUserCropsInteractor, PlanSaveEnsureUserFarmInteractor,
    PlanSaveEnsureUserFieldsInteractor, PlanSaveEnsureUserFertilizesInteractor,
    PlanSaveEnsureUserInteractionRulesInteractor, PlanSaveEnsureUserPesticidesInteractor,
    PlanSaveEnsureUserPestsInteractor, PlanSavePersistOrchestrator, PlanSaveSessionRef,
};
use agrr_domain::cultivation_plan::ports::UserAgriculturalTaskMappingPort;
use agrr_domain::shared::exceptions::InvalidTaskScheduleItemError;
use agrr_domain::shared::ports::{ClockPort, LoggerPort, TranslatorPort};

use super::plan_save_gateways::{
    CropLimitGw, CropTaskScheduleBlueprintGw, PlanSaveFarmGw,
    PlanSaveFieldGw, PlanSaveUserAgriculturalTaskGw, PlanSaveUserCropGw, PlanSaveUserFertilizeGw,
    PlanSaveUserInteractionRuleGw, PlanSaveUserPestGw, PlanSaveUserPesticideGw,
};
use super::plan_save_plan_copy::{PlanSaveContext, PlanSavePlanCopy};
use super::PublicPlanSaveReadSqliteGateway;

pub(crate) struct PlanSaveSessionResult {
    pub success: bool,
    pub error_message: Option<String>,
    pub new_cultivation_plan_id: Option<i64>,
    pub skipped_items: PublicPlanSaveSkippedItems,
}

struct TaskMapping<'a> {
    map: &'a HashMap<i64, i64>,
    user_id: i64,
    gateway: &'a PlanSaveUserAgriculturalTaskGw,
}

impl UserAgriculturalTaskMappingPort for TaskMapping<'_> {
    fn user_task_id_for(&self, reference_task_id: Option<i64>) -> Option<i64> {
        let reference_task_id = reference_task_id?;
        if let Some(id) = self.map.get(&reference_task_id) {
            return Some(*id);
        }
        self.gateway
            .find_by_user_id_and_source_agricultural_task_id(self.user_id, reference_task_id)
            .ok()
            .flatten()
            .map(|s| s.id)
    }
}

pub(crate) struct PlanSaveSession<'a, L, T, C> {
    pool: SqlitePool,
    workspace: &'a PublicPlanSaveWorkspace,
    logger: &'a L,
    translator: &'a T,
    clock: &'a C,
}

impl<'a, L, T, C> PlanSaveSession<'a, L, T, C>
where
    L: LoggerPort,
    T: TranslatorPort,
    C: ClockPort,
{
    pub fn new(
        pool: SqlitePool,
        workspace: &'a PublicPlanSaveWorkspace,
        logger: &'a L,
        translator: &'a T,
        clock: &'a C,
    ) -> Self {
        Self {
            pool,
            workspace,
            logger,
            translator,
            clock,
        }
    }

    pub fn call(
        self,
    ) -> Result<PlanSaveSessionResult, Box<dyn std::error::Error + Send + Sync>> {
        let mut result = PlanSaveSessionResult {
            success: false,
            error_message: None,
            new_cultivation_plan_id: None,
            skipped_items: PublicPlanSaveSkippedItems::default(),
        };
        match self.run_persist_steps(&mut result) {
            Ok(()) => Ok(result),
            Err(err) if err.downcast_ref::<InvalidTaskScheduleItemError>().is_some() => Err(err),
            Err(err) => {
                result.error_message = Some(err.to_string());
                Ok(result)
            }
        }
    }

    fn run_persist_steps(
        &self,
        result: &mut PlanSaveSessionResult,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user_id = self.workspace.user_id;
        let session = &self.workspace.session_data;
        let plan_id = session.plan_id;

        let farm_gw = PlanSaveFarmGw::new(self.pool.clone());
        let farm_interactor =
            PlanSaveEnsureUserFarmInteractor::new(&farm_gw, self.logger, self.translator, self.clock);
        let orchestrator = PlanSavePersistOrchestrator::new(&farm_interactor);
        let farm_output = orchestrator.ensure_user_farm(
            user_id,
            PlanSaveSessionRef::Dto(session),
        )?;

        if farm_output.farm_reused {
            result.skipped_items.add_skip("farm", farm_output.farm_id);
        }

        let farm_record = farm_gw
            .find_owned_farm_record(user_id, farm_output.farm_id)?
            .ok_or_else(|| {
                Box::new(PlanSaveRecordNotFoundError(format!(
                    "User farm not found: {}",
                    farm_output.farm_id
                ))) as Box<dyn std::error::Error + Send + Sync>
            })?;
        let farm_id = farm_record
            .get("id")
            .and_then(|v| v.as_i64())
            .unwrap_or(farm_output.farm_id);
        let farm_region = farm_output.farm_region;

        let field_gw = PlanSaveFieldGw::new(self.pool.clone());
        let fields_interactor =
            PlanSaveEnsureUserFieldsInteractor::new(&field_gw, self.logger, self.translator);
        let field_output = fields_interactor.call(PlanSaveEnsureUserFieldsInput {
            user_id,
            farm_id,
            farm_reused: farm_output.farm_reused,
            field_data: session.field_data.clone(),
        })?;
        for id in &field_output.skipped_field_ids {
            result.skipped_items.add_skip("fields", *id);
        }

        let read_gw = PublicPlanSaveReadSqliteGateway::new(self.pool.clone());
        let crop_gw = PlanSaveUserCropGw::new(self.pool.clone());
        let limit_gw = CropLimitGw::new(self.pool.clone());
        let crops_interactor = PlanSaveEnsureUserCropsInteractor::new(
            &read_gw,
            &crop_gw,
            &limit_gw,
            self.logger,
            self.translator,
        );
        let crop_output = crops_interactor.call(PlanSaveEnsureUserCropsInput {
            user_id,
            plan_id,
        })?;
        for id in &crop_output.skipped_crop_ids {
            result.skipped_items.add_skip("crops", *id);
        }

        let crop_gateway = CropSqliteGateway::new(self.pool.clone());
        let stage_copy = CropStageCopyInteractor::new(&crop_gateway);
        // Run for every reference→user crop mapping so re-save backfills requirements on reused crops.
        for (&reference_crop_id, &new_crop_id) in &crop_output.reference_crop_id_to_user_crop_id {
            stage_copy.call(CropStageCopyInput {
                reference_crop_id,
                new_crop_id,
            })?;
        }

        let pest_gw = PlanSaveUserPestGw::new(self.pool.clone());
        let pests_interactor =
            PlanSaveEnsureUserPestsInteractor::new(&read_gw, &pest_gw, self.logger, self.translator);
        let pest_output = pests_interactor.call(PlanSaveEnsureUserPestsInput {
            user_id,
            plan_id,
            region: farm_region.clone(),
            reference_crop_id_to_user_crop_id: crop_output.reference_crop_id_to_user_crop_id.clone(),
        })?;
        for id in &pest_output.skipped_pest_ids {
            result.skipped_items.add_skip("pests", *id);
        }

        let ag_gw = PlanSaveUserAgriculturalTaskGw::new(self.pool.clone());
        let ag_interactor = PlanSaveEnsureUserAgriculturalTasksInteractor::new(
            &read_gw,
            &ag_gw,
            self.logger,
            self.translator,
        );
        let ag_output = ag_interactor.call(PlanSaveEnsureUserAgriculturalTasksInput {
            user_id,
            region: farm_region.clone(),
            reference_crop_id_to_user_crop_id: crop_output.reference_crop_id_to_user_crop_id.clone(),
        })?;
        for id in &ag_output.skipped_agricultural_task_ids {
            result.skipped_items.add_skip("agricultural_tasks", *id);
        }

        let ir_gw = PlanSaveUserInteractionRuleGw::new(self.pool.clone());
        let ir_interactor = PlanSaveEnsureUserInteractionRulesInteractor::new(
            &read_gw,
            &ir_gw,
            self.logger,
            self.translator,
        );
        let ir_output = ir_interactor.call(PlanSaveEnsureUserInteractionRulesInput {
            user_id,
            region: farm_region.clone(),
            reference_crop_groups: crop_output.reference_crop_groups.clone(),
        })?;
        for id in &ir_output.skipped_interaction_rule_ids {
            result.skipped_items.add_skip("interaction_rules", *id);
        }

        let fertilize_gw = PlanSaveUserFertilizeGw::new(self.pool.clone());
        let fertilize_interactor = PlanSaveEnsureUserFertilizesInteractor::new(
            &read_gw,
            &fertilize_gw,
            self.logger,
            self.translator,
        );
        let fertilize_output = fertilize_interactor.call(PlanSaveEnsureUserFertilizesInput {
            user_id,
            region: farm_region.clone(),
        })?;
        for id in &fertilize_output.skipped_fertilize_ids {
            result.skipped_items.add_skip("fertilizes", *id);
        }

        let pesticide_gw = PlanSaveUserPesticideGw::new(self.pool.clone());
        let pesticide_interactor = PlanSaveEnsureUserPesticidesInteractor::new(
            &read_gw,
            &pesticide_gw,
            self.logger,
            self.translator,
        );
        let pesticide_output = pesticide_interactor.call(PlanSaveEnsureUserPesticidesInput {
            user_id,
            region: farm_region,
            reference_crop_id_to_user_crop_id: crop_output.reference_crop_id_to_user_crop_id.clone(),
            reference_pest_id_to_user_pest_id: pest_output.reference_pest_id_to_user_pest_id.clone(),
        })?;
        for id in &pesticide_output.skipped_pesticide_ids {
            result.skipped_items.add_skip("pesticides", *id);
        }

        if let Some(existing) = farm_gw.find_owned_private_plan_record(user_id, farm_id)? {
            let existing_id = existing
                .get("id")
                .and_then(|v| v.as_i64())
                .unwrap_or_default();
            result.skipped_items.add_skip("plan", existing_id);
            result.success = true;
            result.new_cultivation_plan_id = Some(existing_id);
            return Ok(());
        }

        let mut ctx = PlanSaveContext {
            user_id,
            session_data: session.clone(),
            ref_cpc_id_to_user_crop_id: crop_output.ref_cpc_id_to_user_crop_id.clone(),
            reference_agricultural_task_id_to_user_task_id: ag_output
                .reference_agricultural_task_id_to_user_task_id
                .clone(),
        };

        let new_plan_id = {
            let plan_copy = PlanSavePlanCopy::new(self.pool.clone(), &mut ctx, self.clock);
            let id = plan_copy.copy_cultivation_plan(farm_id)?;
            plan_copy.establish_master_data_relationships();
            id
        };

        let blueprint_gw = CropTaskScheduleBlueprintGw::new(self.pool.clone());
        let task_mapping = TaskMapping {
            map: &ctx.reference_agricultural_task_id_to_user_task_id,
            user_id,
            gateway: &ag_gw,
        };
        let blueprint_copy = CropTaskScheduleBlueprintCopyInteractor::new(
            &blueprint_gw,
            &task_mapping,
            self.logger,
        );
        blueprint_copy.call(CropTaskScheduleBlueprintCopyInput::from_map(
            crop_output.reference_crop_id_to_user_crop_id.clone(),
        ))?;

        let fc_map = {
            let plan_copy = PlanSavePlanCopy::new(self.pool.clone(), &mut ctx, self.clock);
            plan_copy.copy_plan_relations(new_plan_id)?
        };
        {
            let mut plan_copy = PlanSavePlanCopy::new(self.pool.clone(), &mut ctx, self.clock);
            plan_copy.copy_task_schedules(new_plan_id, &fc_map)?;
        }

        result.success = true;
        result.new_cultivation_plan_id = Some(new_plan_id);
        Ok(())
    }
}

pub(crate) fn session_output_from_result(
    result: PlanSaveSessionResult,
) -> PublicPlanSaveFromSessionOutput {
    if result.success {
        PublicPlanSaveFromSessionOutput::success_with(
            result.new_cultivation_plan_id,
            result.skipped_items,
        )
    } else {
        PublicPlanSaveFromSessionOutput::failure(
            result
                .error_message
                .unwrap_or_else(|| "plan save failed".into()),
        )
    }
}
