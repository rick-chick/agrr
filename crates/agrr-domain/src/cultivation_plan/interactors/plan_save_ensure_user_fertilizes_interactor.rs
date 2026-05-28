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
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::{
        PlanSaveUserFertilizeSnapshot, PublicPlanSaveFertilizeReferenceRow,
        PublicPlanSaveFieldDatum, PublicPlanSaveHeaderSnapshot,
    };
    use crate::cultivation_plan::interactors::plan_save_test_support::{
        CapturingLogger, FakeTranslator,
    };
    use std::sync::atomic::{AtomicUsize, Ordering};

    struct MockRead {
        rows: Vec<PublicPlanSaveFertilizeReferenceRow>,
        name_taken: AtomicUsize,
    }

    impl PublicPlanSaveReadGateway for MockRead {
        fn find_header(&self, _: i64) -> Result<Option<PublicPlanSaveHeaderSnapshot>, Box<dyn std::error::Error + Send + Sync>> { Ok(None) }
        fn list_field_rows(&self, _: i64) -> Result<Vec<PublicPlanSaveFieldDatum>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_crop_reference_rows(&self, _: i64) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveCropReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_pest_reference_rows(&self, _: i64, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSavePestReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_pesticide_reference_rows(&self, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSavePesticideReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_fertilize_reference_rows(&self, _: Option<&str>) -> Result<Vec<PublicPlanSaveFertilizeReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(self.rows.clone()) }
        fn exists_fertilize_name(&self, name: &str) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
            if name == "肥料A (コピー)" {
                Ok(self.name_taken.load(Ordering::SeqCst) > 0)
            } else {
                Ok(false)
            }
        }
        fn list_agricultural_task_reference_rows(&self, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveAgriculturalTaskReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_interaction_rule_reference_rows(&self, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveInteractionRuleReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
    }

    struct MockUserFertilize {
        existing: Option<i64>,
    }

    impl PlanSaveUserFertilizeGateway for MockUserFertilize {
        fn find_by_user_id_and_source_fertilize_id(&self, _: i64, _: i64) -> Result<Option<PlanSaveUserFertilizeSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.existing.map(|id| PlanSaveUserFertilizeSnapshot { id, name: Some("既存".into()) }))
        }
        fn create(&self, _: i64, attrs: crate::shared::attr::AttrMap) -> Result<PlanSaveUserFertilizeSnapshot, Box<dyn std::error::Error + Send + Sync>> {
            let name = attrs.get("name").and_then(|v| v.as_str()).unwrap_or("").to_string();
            Ok(PlanSaveUserFertilizeSnapshot { id: 88, name: Some(name) })
        }
    }

    #[test]
    fn creates_user_fertilize_with_copy_suffix_name() {
        let read = MockRead {
            rows: vec![PublicPlanSaveFertilizeReferenceRow {
                reference_fertilize_id: 200,
                name: Some("肥料A".into()),
                n: Some(10.0),
                p: Some(5.0),
                k: Some(8.0),
                description: None,
                package_size: None,
                region: Some("jp".into()),
            }],
            name_taken: AtomicUsize::new(0),
        };
        let user_gw = MockUserFertilize { existing: None };
        let logger = CapturingLogger::new();
        let out = PlanSaveEnsureUserFertilizesInteractor::new(&read, &user_gw, &logger, &FakeTranslator)
            .call(PlanSaveEnsureUserFertilizesInput { user_id: 1, region: Some("jp".into()) })
            .unwrap();
        assert_eq!(out.user_fertilize_ids, vec![88]);
    }

    #[test]
    fn reuses_existing_user_fertilize_and_records_skip() {
        let read = MockRead { rows: vec![PublicPlanSaveFertilizeReferenceRow {
            reference_fertilize_id: 200, name: Some("肥料A".into()), n: None, p: None, k: None,
            description: None, package_size: None, region: Some("jp".into()),
        }], name_taken: AtomicUsize::new(0) };
        let user_gw = MockUserFertilize { existing: Some(77) };
        let logger = CapturingLogger::new();
        let out = PlanSaveEnsureUserFertilizesInteractor::new(&read, &user_gw, &logger, &FakeTranslator)
            .call(PlanSaveEnsureUserFertilizesInput { user_id: 1, region: Some("jp".into()) })
            .unwrap();
        assert_eq!(out.user_fertilize_ids, vec![77]);
        assert_eq!(out.skipped_fertilize_ids, vec![77]);
    }
}
