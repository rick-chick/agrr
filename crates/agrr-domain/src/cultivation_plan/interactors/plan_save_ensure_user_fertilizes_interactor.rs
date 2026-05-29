//! Ruby: `Domain::CultivationPlan::Interactors::PlanSaveEnsureUserFertilizesInteractor`

use std::collections::BTreeMap;

use crate::cultivation_plan::dtos::{
    PlanSaveEnsureUserFertilizesInput, PlanSaveEnsureUserFertilizesOutput,
};
use crate::cultivation_plan::gateways::{PlanSaveUserFertilizeGateway, PublicPlanSaveReadGateway};
use crate::cultivation_plan::helpers::attr_map_from_json;
use crate::cultivation_plan::mappers::{
    fertilize_attributes_for_create, resolve_fertilize_unique_name,
};
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::{LoggerPort, TranslatorPort};

pub struct PlanSaveEnsureUserFertilizesInteractor<'a, R, U, L, T> {
    read_gateway: &'a R,
    user_fertilize_gateway: &'a U,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, R, U, L, T> PlanSaveEnsureUserFertilizesInteractor<'a, R, U, L, T>
where
    R: PublicPlanSaveReadGateway,
    U: PlanSaveUserFertilizeGateway,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        read_gateway: &'a R,
        user_fertilize_gateway: &'a U,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            read_gateway,
            user_fertilize_gateway,
            logger,
            translator,
        }
    }

    pub fn call(
        &self,
        input: PlanSaveEnsureUserFertilizesInput,
    ) -> Result<PlanSaveEnsureUserFertilizesOutput, Box<dyn std::error::Error + Send + Sync>> {
        let rows = self
            .read_gateway
            .list_fertilize_reference_rows(input.region.as_deref())?;
        let mut user_fertilize_ids = Vec::new();
        let mut skipped_fertilize_ids = Vec::new();

        for row in rows {
            if let Some(existing) = self.user_fertilize_gateway.find_by_user_id_and_source_fertilize_id(
                input.user_id,
                row.reference_fertilize_id,
            )? {
                skipped_fertilize_ids.push(existing.id);
                user_fertilize_ids.push(existing.id);
                continue;
            }

            let base_name = row.name.clone().unwrap_or_default();
            let unique_name = resolve_fertilize_unique_name(&base_name, |candidate| {
                self.read_gateway
                    .exists_fertilize_name(candidate)
                    .unwrap_or(true)
            })
            .ok_or_else(|| {
                Box::new(RecordInvalidError::new(
                    Some("fertilize unique name exhausted".into()),
                    None,
                )) as Box<dyn std::error::Error + Send + Sync>
            })?;

            let attributes = attr_map_from_json(fertilize_attributes_for_create(
                &row,
                input.region.as_deref(),
                &unique_name,
            ));
            let created = self
                .user_fertilize_gateway
                .create(input.user_id, attributes)?;

            user_fertilize_ids.push(created.id);
            self.logger.info(&self.translator.t(
                "services.plan_save_service.messages.fertilize_created",
                &BTreeMap::from([(
                    "fertilize_name".into(),
                    created.name.clone().unwrap_or_default(),
                )]),
            ));
        }

        Ok(PlanSaveEnsureUserFertilizesOutput {
            user_fertilize_ids,
            skipped_fertilize_ids,
        })
    }
}

#[cfg(test)]
mod interactors_plan_save_ensure_user_fertilizes_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_plan_save_ensure_user_fertilizes_interactor_test.rs"));
}
