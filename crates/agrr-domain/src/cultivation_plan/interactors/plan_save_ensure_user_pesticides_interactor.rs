//! Ruby: `Domain::CultivationPlan::Interactors::PlanSaveEnsureUserPesticidesInteractor`

use std::collections::BTreeMap;

use crate::cultivation_plan::dtos::{
    PlanSaveEnsureUserPesticidesInput, PlanSaveEnsureUserPesticidesOutput,
};
use crate::cultivation_plan::gateways::{PlanSaveUserPesticideGateway, PublicPlanSaveReadGateway};
use crate::cultivation_plan::helpers::attr_map_from_json;
use crate::cultivation_plan::mappers::PlanSavePesticideAttributesMapper;
use crate::shared::ports::{LoggerPort, TranslatorPort};

pub struct PlanSaveEnsureUserPesticidesInteractor<'a, R, U, L, T> {
    read_gateway: &'a R,
    user_pesticide_gateway: &'a U,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, R, U, L, T> PlanSaveEnsureUserPesticidesInteractor<'a, R, U, L, T>
where
    R: PublicPlanSaveReadGateway,
    U: PlanSaveUserPesticideGateway,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        read_gateway: &'a R,
        user_pesticide_gateway: &'a U,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            read_gateway,
            user_pesticide_gateway,
            logger,
            translator,
        }
    }

    pub fn call(
        &self,
        input: PlanSaveEnsureUserPesticidesInput,
    ) -> Result<PlanSaveEnsureUserPesticidesOutput, Box<dyn std::error::Error + Send + Sync>> {
        let rows = self
            .read_gateway
            .list_pesticide_reference_rows(input.region.as_deref())?;

        let mut user_pesticide_ids = Vec::new();
        let mut skipped_pesticide_ids = Vec::new();

        for row in rows {
            let Some(user_crop_id) = input
                .reference_crop_id_to_user_crop_id
                .get(&row.reference_crop_id)
            else {
                self.logger.warn(&format!(
                    "Skipping pesticide copy due to missing crop/pest mapping \
                     (pesticide_id={})",
                    row.reference_pesticide_id
                ));
                continue;
            };
            let Some(user_pest_id) = input
                .reference_pest_id_to_user_pest_id
                .get(&row.reference_pest_id)
            else {
                self.logger.warn(&format!(
                    "Skipping pesticide copy due to missing crop/pest mapping \
                     (pesticide_id={})",
                    row.reference_pesticide_id
                ));
                continue;
            };

            if let Some(existing) = self
                .user_pesticide_gateway
                .find_by_user_id_and_source_pesticide_id(
                    input.user_id,
                    row.reference_pesticide_id,
                )?
            {
                skipped_pesticide_ids.push(existing.id);
                user_pesticide_ids.push(existing.id);
                continue;
            }

            let attributes = attr_map_from_json(PlanSavePesticideAttributesMapper::attributes_for_create(
                &row,
                input.region.as_deref(),
                *user_crop_id,
                *user_pest_id,
            ));
            let usage = PlanSavePesticideAttributesMapper::usage_constraint_attributes(&row)
                .map(attr_map_from_json);
            let detail = PlanSavePesticideAttributesMapper::application_detail_attributes(&row)
                .map(attr_map_from_json);

            let created = self.user_pesticide_gateway.create(
                input.user_id,
                attributes,
                usage,
                detail,
            )?;

            user_pesticide_ids.push(created.id);
            self.logger.info(&self.translator.t(
                "services.plan_save_service.messages.pesticide_created",
                &BTreeMap::from([(
                    "pesticide_name".into(),
                    created.name.clone().unwrap_or_default(),
                )]),
            ));
        }

        Ok(PlanSaveEnsureUserPesticidesOutput {
            user_pesticide_ids,
            skipped_pesticide_ids,
        })
    }
}

#[cfg(test)]
mod interactors_plan_save_ensure_user_pesticides_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_plan_save_ensure_user_pesticides_interactor_test.rs"));
}
