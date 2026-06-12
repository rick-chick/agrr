//! Ruby: `Domain::CultivationPlan::Interactors::PlanSaveEnsureUserCropsInteractor`

use std::collections::{BTreeMap, HashMap};

use crate::crop::policies::crop_create_limit_policy;
use crate::crop::policies::crop_reference_record_policy::region_matches;
use crate::cultivation_plan::dtos::{
    PlanSaveCropStageCopyPair, PlanSaveEnsureUserCropsInput, PlanSaveEnsureUserCropsOutput,
    PublicPlanSaveCropReferenceRow,
};
use crate::cultivation_plan::gateways::{
    PlanSaveCropLimitGateway, PlanSaveUserCropGateway, PublicPlanSaveReadGateway,
};
use crate::shared::attr::{attr_map_from_pairs, AttrValue};
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::{LoggerPort, TranslatorPort};

pub struct PlanSaveEnsureUserCropsInteractor<'a, R, U, C, L, T> {
    read_gateway: &'a R,
    user_crop_gateway: &'a U,
    crop_gateway: &'a C,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, R, U, C, L, T> PlanSaveEnsureUserCropsInteractor<'a, R, U, C, L, T>
where
    R: PublicPlanSaveReadGateway,
    U: PlanSaveUserCropGateway,
    C: PlanSaveCropLimitGateway,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        read_gateway: &'a R,
        user_crop_gateway: &'a U,
        crop_gateway: &'a C,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            read_gateway,
            user_crop_gateway,
            crop_gateway,
            logger,
            translator,
        }
    }

    pub fn call(
        &self,
        input: PlanSaveEnsureUserCropsInput,
    ) -> Result<PlanSaveEnsureUserCropsOutput, Box<dyn std::error::Error + Send + Sync>> {
        if input.plan_id == 0 {
            return Err(Box::new(RecordInvalidError::new(
                Some("plan_id is required to derive crops".into()),
                None,
            )));
        }

        let reference_rows = self.read_gateway.list_crop_reference_rows(input.plan_id)?;
        let reference_crop_groups = reference_crop_groups_from_rows(&reference_rows);
        let mut user_crop_ids = Vec::new();
        let mut skipped_crop_ids = Vec::new();
        let mut reference_crop_id_to_user_crop_id = HashMap::new();
        let mut ref_cpc_id_to_user_crop_id = HashMap::new();
        let mut stage_copy_pairs = Vec::new();

        for row in reference_rows {
            if !region_matches(input.region.as_deref(), row.region.as_deref()) {
                continue;
            }

            if let Some(existing) = self
                .user_crop_gateway
                .find_by_user_id_and_source_crop_id(input.user_id, row.reference_crop_id)?
            {
                skipped_crop_ids.push(existing.id);
                user_crop_ids.push(existing.id);
                reference_crop_id_to_user_crop_id.insert(row.reference_crop_id, existing.id);
                ref_cpc_id_to_user_crop_id.insert(row.cultivation_plan_crop_id, existing.id);
                continue;
            }

            self.enforce_crop_create_limit(input.user_id)?;

            let attributes = crop_attributes_from_row(&row);
            let created = self
                .user_crop_gateway
                .create(input.user_id, attributes)?;

            user_crop_ids.push(created.id);
            reference_crop_id_to_user_crop_id.insert(row.reference_crop_id, created.id);
            ref_cpc_id_to_user_crop_id.insert(row.cultivation_plan_crop_id, created.id);
            stage_copy_pairs.push(PlanSaveCropStageCopyPair {
                reference_crop_id: row.reference_crop_id,
                new_crop_id: created.id,
            });
        }

        self.logger.info(&self.translator.t(
            "services.plan_save_service.debug.user_crops_created",
            &BTreeMap::from([("count".into(), user_crop_ids.len().to_string())]),
        ));

        Ok(PlanSaveEnsureUserCropsOutput {
            user_crop_ids,
            skipped_crop_ids,
            reference_crop_id_to_user_crop_id,
            ref_cpc_id_to_user_crop_id,
            stage_copy_pairs,
            reference_crop_groups,
        })
    }

    fn enforce_crop_create_limit(
        &self,
        user_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let existing_count = self
            .crop_gateway
            .count_user_owned_non_reference_crops(user_id)?;
        if crop_create_limit_policy::limit_exceeded(existing_count, false) {
            return Err(Box::new(RecordInvalidError::new(
                Some(
                    self.translator
                        .t(
                            "activerecord.errors.models.crop.attributes.user.crop_limit_exceeded",
                            &BTreeMap::new(),
                        ),
                ),
                None,
            )));
        }
        Ok(())
    }
}

fn crop_attributes_from_row(row: &PublicPlanSaveCropReferenceRow) -> crate::shared::attr::AttrMap {
    attr_map_from_pairs([
        ("name", AttrValue::from(row.name.clone().unwrap_or_default())),
        (
            "variety",
            row.variety
                .clone()
                .map(AttrValue::from)
                .unwrap_or(AttrValue::Null),
        ),
        (
            "area_per_unit",
            row.area_per_unit
                .map(|v| AttrValue::Str(v.to_string()))
                .unwrap_or(AttrValue::Null),
        ),
        (
            "revenue_per_area",
            row.revenue_per_area
                .map(|v| AttrValue::Str(v.to_string()))
                .unwrap_or(AttrValue::Null),
        ),
        (
            "groups",
            row.groups
                .clone()
                .map(|g| AttrValue::Str(serde_json::to_string(&g).unwrap_or_default()))
                .unwrap_or(AttrValue::Null),
        ),
        ("is_reference", AttrValue::Bool(false)),
        (
            "region",
            row.region
                .clone()
                .map(AttrValue::from)
                .unwrap_or(AttrValue::Null),
        ),
        ("source_crop_id", AttrValue::Int(row.reference_crop_id)),
    ])
}

fn reference_crop_groups_from_rows(rows: &[PublicPlanSaveCropReferenceRow]) -> Vec<String> {
    let mut groups = Vec::new();
    for row in rows {
        if let Some(name) = row.name.as_ref().filter(|n| !n.is_empty()) {
            groups.push(name.clone());
        }
        if let Some(gs) = &row.groups {
            groups.extend(gs.iter().cloned());
        }
    }
    groups.sort();
    groups.dedup();
    groups
}

#[cfg(test)]
mod interactors_plan_save_ensure_user_crops_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_plan_save_ensure_user_crops_interactor_test.rs"));
}
