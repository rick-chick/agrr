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
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::{PlanSaveFieldSnapshot, PublicPlanSaveFieldDatum};
    use crate::cultivation_plan::interactors::plan_save_test_support::{
        CapturingLogger, FakeTranslator,
    };
    use crate::shared::attr::{AttrMap, AttrValue};

    struct MockFieldGateway {
        existing: Vec<PlanSaveFieldSnapshot>,
        created_id: i64,
    }

    impl PlanSaveFieldGateway for MockFieldGateway {
        fn list_by_farm_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Vec<PlanSaveFieldSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.existing.clone())
        }

        fn create(
            &self,
            _: i64,
            _: i64,
            attributes: AttrMap,
        ) -> Result<PlanSaveFieldSnapshot, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(attributes.get("name"), Some(&AttrValue::from("区画A")));
            assert_eq!(
                attributes.get("description"),
                Some(&AttrValue::from(
                    "services.plan_save_service.messages.coordinates|{:lat=>35.0, :lng=>139.0}"
                ))
            );
            Ok(PlanSaveFieldSnapshot {
                id: self.created_id,
                name: Some("区画".into()),
                area: Some(1.0),
                farm_id: 5,
                user_id: 1,
            })
        }
    }

    fn field_datum() -> PublicPlanSaveFieldDatum {
        PublicPlanSaveFieldDatum::new(Some("区画A"), Some(12.5), vec![35.0, 139.0])
    }

    #[test]
    fn reuses_existing_fields_and_records_skips_when_farm_reused() {
        let out = PlanSaveEnsureUserFieldsInteractor::new(
            &MockFieldGateway {
                existing: vec![
                    PlanSaveFieldSnapshot {
                        id: 10,
                        name: None,
                        area: None,
                        farm_id: 5,
                        user_id: 1,
                    },
                    PlanSaveFieldSnapshot {
                        id: 11,
                        name: None,
                        area: None,
                        farm_id: 5,
                        user_id: 1,
                    },
                ],
                created_id: 0,
            },
            &CapturingLogger::new(),
            &FakeTranslator,
        )
        .call(PlanSaveEnsureUserFieldsInput {
            user_id: 1,
            farm_id: 5,
            farm_reused: true,
            field_data: vec![field_datum()],
        })
        .unwrap();
        assert_eq!(out.field_ids, vec![10, 11]);
        assert_eq!(out.skipped_field_ids, vec![10, 11]);
    }

    #[test]
    fn creates_fields_from_session_when_farm_is_new() {
        let out = PlanSaveEnsureUserFieldsInteractor::new(
            &MockFieldGateway {
                existing: vec![],
                created_id: 99,
            },
            &CapturingLogger::new(),
            &FakeTranslator,
        )
        .call(PlanSaveEnsureUserFieldsInput {
            user_id: 1,
            farm_id: 5,
            farm_reused: false,
            field_data: vec![field_datum()],
        })
        .unwrap();
        assert_eq!(out.field_ids, vec![99]);
        assert!(out.skipped_field_ids.is_empty());
    }

    #[test]
    fn returns_empty_field_ids_when_field_data_empty_and_farm_new() {
        let out = PlanSaveEnsureUserFieldsInteractor::new(
            &MockFieldGateway {
                existing: vec![],
                created_id: 0,
            },
            &CapturingLogger::new(),
            &FakeTranslator,
        )
        .call(PlanSaveEnsureUserFieldsInput {
            user_id: 1,
            farm_id: 5,
            farm_reused: false,
            field_data: vec![],
        })
        .unwrap();
        assert!(out.field_ids.is_empty());
        assert!(out.skipped_field_ids.is_empty());
    }
}
