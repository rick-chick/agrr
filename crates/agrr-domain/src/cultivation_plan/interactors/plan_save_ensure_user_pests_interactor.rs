//! Ruby: `Domain::CultivationPlan::Interactors::PlanSaveEnsureUserPestsInteractor`

use std::collections::{BTreeMap, HashMap};

use crate::cultivation_plan::dtos::{
    PlanSaveEnsureUserPestsInput, PlanSaveEnsureUserPestsOutput, PublicPlanSavePestReferenceRow,
};
use crate::cultivation_plan::gateways::{PlanSaveUserPestGateway, PublicPlanSaveReadGateway};
use crate::cultivation_plan::helpers::attr_map_from_json;
use crate::cultivation_plan::mappers::pest_attributes_for_create;
use crate::shared::attr::{attr_map_from_pairs, AttrValue};
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::ports::{LoggerPort, TranslatorPort};

struct PestCreateResult {
    id: i64,
    name: Option<String>,
    skipped_reuse: bool,
}

pub struct PlanSaveEnsureUserPestsInteractor<'a, R, U, L, T> {
    read_gateway: &'a R,
    user_pest_gateway: &'a U,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, R, U, L, T> PlanSaveEnsureUserPestsInteractor<'a, R, U, L, T>
where
    R: PublicPlanSaveReadGateway,
    U: PlanSaveUserPestGateway,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        read_gateway: &'a R,
        user_pest_gateway: &'a U,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            read_gateway,
            user_pest_gateway,
            logger,
            translator,
        }
    }

    pub fn call(
        &self,
        input: PlanSaveEnsureUserPestsInput,
    ) -> Result<PlanSaveEnsureUserPestsOutput, Box<dyn std::error::Error + Send + Sync>> {
        if input.reference_crop_id_to_user_crop_id.is_empty() {
            return Ok(PlanSaveEnsureUserPestsOutput {
                user_pest_ids: vec![],
                skipped_pest_ids: vec![],
                reference_pest_id_to_user_pest_id: HashMap::new(),
            });
        }

        let reference_crop_ids: Vec<i64> = input.reference_crop_ids();
        let rows = self.read_gateway.list_pest_reference_rows(
            input.plan_id,
            input.region.as_deref(),
        )?;

        let mut user_pest_ids = Vec::new();
        let mut skipped_pest_ids = Vec::new();
        let mut reference_pest_id_to_user_pest_id = HashMap::new();

        for row in rows {
            if !row_intersects_plan_crops(&row, &reference_crop_ids) {
                continue;
            }

            if let Some(existing) = self
                .user_pest_gateway
                .find_by_user_id_and_source_pest_id(input.user_id, row.reference_pest_id)?
            {
                self.sync_crop_pest_links(&row, existing.id, &input.reference_crop_id_to_user_crop_id);
                skipped_pest_ids.push(existing.id);
                user_pest_ids.push(existing.id);
                reference_pest_id_to_user_pest_id.insert(row.reference_pest_id, existing.id);
                continue;
            }

            let user_pest = self.create_user_pest_with_children(
                &input,
                &row,
                &input.reference_crop_id_to_user_crop_id,
            )?;

            user_pest_ids.push(user_pest.id);
            if user_pest.skipped_reuse {
                skipped_pest_ids.push(user_pest.id);
            }
            reference_pest_id_to_user_pest_id.insert(row.reference_pest_id, user_pest.id);
            if !user_pest.skipped_reuse {
                self.logger.info(&self.translator.t(
                    "services.plan_save_service.messages.pest_created",
                    &BTreeMap::from([(
                        "pest_name".into(),
                        user_pest.name.clone().unwrap_or_default(),
                    )]),
                ));
            }
        }

        Ok(PlanSaveEnsureUserPestsOutput {
            user_pest_ids,
            skipped_pest_ids,
            reference_pest_id_to_user_pest_id,
        })
    }

    fn sync_crop_pest_links(
        &self,
        row: &PublicPlanSavePestReferenceRow,
        user_pest_id: i64,
        reference_crop_id_to_user_crop_id: &HashMap<i64, i64>,
    ) {
        for reference_crop_id in &row.linked_reference_crop_ids {
            if let Some(user_crop_id) = reference_crop_id_to_user_crop_id.get(reference_crop_id) {
                self.user_pest_gateway
                    .link_crop_pest(*user_crop_id, user_pest_id);
            }
        }
    }

    fn create_user_pest_with_children(
        &self,
        input: &PlanSaveEnsureUserPestsInput,
        row: &PublicPlanSavePestReferenceRow,
        reference_crop_id_to_user_crop_id: &HashMap<i64, i64>,
    ) -> Result<PestCreateResult, Box<dyn std::error::Error + Send + Sync>> {
        let attributes = attr_map_from_json(pest_attributes_for_create(
            row,
            input.region.as_deref(),
        ));

        match self.user_pest_gateway.create(input.user_id, attributes) {
            Ok(created) => {
                self.copy_child_records(created.id, row);
                self.sync_crop_pest_links(row, created.id, reference_crop_id_to_user_crop_id);
                Ok(PestCreateResult {
                    id: created.id,
                    name: created.name,
                    skipped_reuse: false,
                })
            }
            Err(err) if uniqueness_violation(err.to_string().as_str()) => {
                let existing = self
                    .user_pest_gateway
                    .find_by_user_id_and_source_pest_id(input.user_id, row.reference_pest_id)?
                    .ok_or_else(|| {
                        Box::new(RecordInvalidError::new(
                            Some(format!(
                                "Pest uniqueness constraint violation but existing pest not found: \
                                 source_pest_id={}, user_id={}",
                                row.reference_pest_id, input.user_id
                            )),
                            None,
                        )) as Box<dyn std::error::Error + Send + Sync>
                    })?;
                self.sync_crop_pest_links(row, existing.id, reference_crop_id_to_user_crop_id);
                Ok(PestCreateResult {
                    id: existing.id,
                    name: existing.name,
                    skipped_reuse: true,
                })
            }
            Err(err) => Err(err),
        }
    }

    fn copy_child_records(&self, pest_id: i64, row: &PublicPlanSavePestReferenceRow) {
        if let Some(profile) = &row.temperature_profile {
            let attrs = attr_map_from_pairs([
                (
                    "base_temperature",
                    profile
                        .base_temperature
                        .map(|v| AttrValue::Str(v.to_string()))
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "max_temperature",
                    profile
                        .max_temperature
                        .map(|v| AttrValue::Str(v.to_string()))
                        .unwrap_or(AttrValue::Null),
                ),
            ]);
            self.user_pest_gateway
                .create_temperature_profile(pest_id, attrs);
        }
        if let Some(thermal) = &row.thermal_requirement {
            let attrs = attr_map_from_pairs([
                (
                    "required_gdd",
                    thermal
                        .required_gdd
                        .map(|v| AttrValue::Str(v.to_string()))
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "first_generation_gdd",
                    thermal
                        .first_generation_gdd
                        .map(|v| AttrValue::Str(v.to_string()))
                        .unwrap_or(AttrValue::Null),
                ),
            ]);
            self.user_pest_gateway
                .create_thermal_requirement(pest_id, attrs);
        }
        for method in &row.control_methods {
            let attrs = attr_map_from_pairs([
                (
                    "method_type",
                    method
                        .method_type
                        .clone()
                        .map(AttrValue::from)
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "method_name",
                    method
                        .method_name
                        .clone()
                        .map(AttrValue::from)
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "description",
                    method
                        .description
                        .clone()
                        .map(AttrValue::from)
                        .unwrap_or(AttrValue::Null),
                ),
                (
                    "timing_hint",
                    method
                        .timing_hint
                        .clone()
                        .map(AttrValue::from)
                        .unwrap_or(AttrValue::Null),
                ),
            ]);
            self.user_pest_gateway.create_control_method(pest_id, attrs);
        }
    }
}

fn row_intersects_plan_crops(row: &PublicPlanSavePestReferenceRow, reference_crop_ids: &[i64]) -> bool {
    row.linked_reference_crop_ids
        .iter()
        .any(|id| reference_crop_ids.contains(id))
}

fn uniqueness_violation(message: &str) -> bool {
    if message.contains("source_pest_id")
        && (message.contains("すでに存在") || message.contains("already") || message.contains("taken"))
    {
        return true;
    }
    (message.contains("Pest") || message.contains("pest"))
        && (message.contains("すでに存在") || message.contains("already") || message.contains("taken"))
}

#[cfg(test)]
mod interactors_plan_save_ensure_user_pests_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_plan_save_ensure_user_pests_interactor_test.rs"));
}
