//! Ruby: `Domain::CultivationPlan::Interactors::PlanSaveEnsureUserFieldsInteractor`

use std::collections::BTreeMap;

use crate::cultivation_plan::dtos::{PlanSaveEnsureUserFieldsInput, PlanSaveEnsureUserFieldsOutput};
use crate::cultivation_plan::gateways::PlanSaveFieldGateway;
use crate::cultivation_plan::helpers::attr_map_from_json;
use crate::cultivation_plan::mappers::{
    field_create_attributes_for_create, PlanSaveFieldTranslator,
};
use crate::shared::ports::{LoggerPort, TranslatorPort};

pub struct PlanSaveEnsureUserFieldsInteractor<'a, G, L, T> {
    gateway: &'a G,
    logger: &'a L,
    translator: &'a T,
}

struct FieldTranslator<'a, T: TranslatorPort + ?Sized> {
    inner: &'a T,
}

impl<T: TranslatorPort + ?Sized> PlanSaveFieldTranslator for FieldTranslator<'_, T> {
    fn coordinates_message(&self, lat: f64, lng: f64) -> String {
        self.inner.t(
            "services.plan_save_service.messages.coordinates",
            &BTreeMap::from([
                ("lat".into(), format_ruby_float(lat)),
                ("lng".into(), format_ruby_float(lng)),
            ]),
        )
    }
}

fn format_ruby_float(v: f64) -> String {
    if v.fract().abs() < f64::EPSILON {
        format!("{v:.1}")
    } else {
        v.to_string()
    }
}

impl<'a, G, L, T> PlanSaveEnsureUserFieldsInteractor<'a, G, L, T>
where
    G: PlanSaveFieldGateway,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(gateway: &'a G, logger: &'a L, translator: &'a T) -> Self {
        Self {
            gateway,
            logger,
            translator,
        }
    }

    pub fn call(
        &self,
        input: PlanSaveEnsureUserFieldsInput,
    ) -> Result<PlanSaveEnsureUserFieldsOutput, Box<dyn std::error::Error + Send + Sync>> {
        if input.farm_reused {
            return Ok(self.ensure_reused_fields(input));
        }
        self.ensure_created_fields(input)
    }

    fn ensure_reused_fields(
        &self,
        input: PlanSaveEnsureUserFieldsInput,
    ) -> PlanSaveEnsureUserFieldsOutput {
        self.logger
            .info("♻️ [PlanSaveService] Skipping field creation because farm was reused");
        let existing = self
            .gateway
            .list_by_farm_id(input.farm_id, input.user_id)
            .unwrap_or_default();
        let ids: Vec<i64> = existing.iter().map(|f| f.id).collect();
        PlanSaveEnsureUserFieldsOutput {
            field_ids: ids.clone(),
            skipped_field_ids: ids,
        }
    }

    fn ensure_created_fields(
        &self,
        input: PlanSaveEnsureUserFieldsInput,
    ) -> Result<PlanSaveEnsureUserFieldsOutput, Box<dyn std::error::Error + Send + Sync>> {
        if input.field_data.is_empty() {
            self.logger.debug(&self.translator.t(
                "services.plan_save_service.debug.field_data_extracted",
                &BTreeMap::from([("field_data".into(), "[]".into())]),
            ));
            return Ok(PlanSaveEnsureUserFieldsOutput {
                field_ids: vec![],
                skipped_field_ids: vec![],
            });
        }

        let field_translator = FieldTranslator {
            inner: self.translator,
        };
        let mut created_ids = Vec::new();
        for datum in &input.field_data {
            let attrs = attr_map_from_json(field_create_attributes_for_create(
                datum,
                &field_translator,
            ));
            let created = self.gateway.create(input.farm_id, input.user_id, attrs)?;
            created_ids.push(created.id);
            self.logger.info(&self.translator.t(
                "services.plan_save_service.messages.field_created",
                &BTreeMap::from([("field_name".into(), datum.name.clone().unwrap_or_default())]),
            ));
        }

        self.logger.info(&self.translator.t(
            "services.plan_save_service.debug.user_fields_created",
            &BTreeMap::from([("count".into(), created_ids.len().to_string())]),
        ));

        Ok(PlanSaveEnsureUserFieldsOutput {
            field_ids: created_ids,
            skipped_field_ids: vec![],
        })
    }
}

#[cfg(test)]
mod interactors_plan_save_ensure_user_fields_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/cultivation_plan/interactors_plan_save_ensure_user_fields_interactor_test.rs"));
}
