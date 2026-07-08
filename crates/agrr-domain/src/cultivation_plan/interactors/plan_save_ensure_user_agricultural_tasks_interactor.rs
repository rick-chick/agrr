//! Ruby: `Domain::CultivationPlan::Interactors::PlanSaveEnsureUserAgriculturalTasksInteractor`

use std::collections::{BTreeMap, HashMap};

use crate::cultivation_plan::dtos::{
    PlanSaveEnsureUserAgriculturalTasksInput, PlanSaveEnsureUserAgriculturalTasksOutput,
    PlanSaveUserAgriculturalTaskSnapshot, PublicPlanSaveAgriculturalTaskReferenceRow,
};
use crate::cultivation_plan::gateways::{
    PlanSaveUserAgriculturalTaskGateway, PublicPlanSaveReadGateway,
};
use crate::cultivation_plan::mappers::agricultural_task_attributes_for_create;
use crate::cultivation_plan::helpers::attr_map_from_json;
use crate::shared::ports::{LoggerPort, TranslatorPort};

pub struct PlanSaveEnsureUserAgriculturalTasksInteractor<'a, R, U, L, T> {
    read_gateway: &'a R,
    user_agricultural_task_gateway: &'a U,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, R, U, L, T> PlanSaveEnsureUserAgriculturalTasksInteractor<'a, R, U, L, T>
where
    R: PublicPlanSaveReadGateway,
    U: PlanSaveUserAgriculturalTaskGateway,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        read_gateway: &'a R,
        user_agricultural_task_gateway: &'a U,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            read_gateway,
            user_agricultural_task_gateway,
            logger,
            translator,
        }
    }

    pub fn call(
        &self,
        input: PlanSaveEnsureUserAgriculturalTasksInput,
    ) -> Result<PlanSaveEnsureUserAgriculturalTasksOutput, Box<dyn std::error::Error + Send + Sync>>
    {
        if input.reference_crop_id_to_user_crop_id.is_empty() {
            return Ok(empty_output());
        }

        let reference_crop_ids: Vec<i64> = input.reference_crop_ids();
        let rows = self
            .read_gateway
            .list_agricultural_task_reference_rows(input.region.as_deref())?;

        let mut user_agricultural_task_ids = Vec::new();
        let mut skipped_agricultural_task_ids = Vec::new();
        let mut reference_agricultural_task_id_to_user_task_id = HashMap::new();

        for row in rows {
            if !row_intersects_plan_crops(&row, &reference_crop_ids) {
                continue;
            }

            if let Some(existing) = self
                .user_agricultural_task_gateway
                .find_by_user_id_and_source_agricultural_task_id(
                    input.user_id,
                    row.reference_agricultural_task_id,
                )?
            {
                skipped_agricultural_task_ids.push(existing.id);
                user_agricultural_task_ids.push(existing.id);
                reference_agricultural_task_id_to_user_task_id
                    .insert(row.reference_agricultural_task_id, existing.id);
                continue;
            }

            let created = self.create_user_agricultural_task(&input, &row)?;
            user_agricultural_task_ids.push(created.id);
            reference_agricultural_task_id_to_user_task_id
                .insert(row.reference_agricultural_task_id, created.id);
            self.logger.info(&self.translator.t(
                "services.plan_save_service.messages.agricultural_task_created",
                &BTreeMap::from([(
                    "task_name".into(),
                    created.name.clone().unwrap_or_default(),
                )]),
            ));
        }

        Ok(PlanSaveEnsureUserAgriculturalTasksOutput {
            user_agricultural_task_ids,
            skipped_agricultural_task_ids,
            reference_agricultural_task_id_to_user_task_id,
        })
    }

    fn create_user_agricultural_task(
        &self,
        input: &PlanSaveEnsureUserAgriculturalTasksInput,
        row: &PublicPlanSaveAgriculturalTaskReferenceRow,
    ) -> Result<PlanSaveUserAgriculturalTaskSnapshot, Box<dyn std::error::Error + Send + Sync>> {
        let attributes = attr_map_from_json(agricultural_task_attributes_for_create(
            row,
            input.region.as_deref(),
        ));
        self.user_agricultural_task_gateway
            .create(input.user_id, attributes)
    }
}

fn empty_output() -> PlanSaveEnsureUserAgriculturalTasksOutput {
    PlanSaveEnsureUserAgriculturalTasksOutput {
        user_agricultural_task_ids: vec![],
        skipped_agricultural_task_ids: vec![],
        reference_agricultural_task_id_to_user_task_id: HashMap::new(),
    }
}

fn row_intersects_plan_crops(row: &PublicPlanSaveAgriculturalTaskReferenceRow, reference_crop_ids: &[i64]) -> bool {
    row.linked_reference_crop_ids
        .iter()
        .any(|id| reference_crop_ids.contains(id))
}

#[cfg(test)]
mod interactors_plan_save_ensure_user_agricultural_tasks_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_plan_save_ensure_user_agricultural_tasks_interactor_test.rs"));
}
