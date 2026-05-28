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
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::{
        PlanSaveUserPesticideSnapshot, PublicPlanSaveFieldDatum, PublicPlanSaveHeaderSnapshot,
        PublicPlanSavePesticideReferenceRow,
    };
    use crate::cultivation_plan::interactors::plan_save_test_support::{
        CapturingLogger, FakeTranslator,
    };
    use std::collections::HashMap;

    struct MockRead {
        rows: Vec<PublicPlanSavePesticideReferenceRow>,
    }

    impl PublicPlanSaveReadGateway for MockRead {
        fn find_header(&self, _: i64) -> Result<Option<PublicPlanSaveHeaderSnapshot>, Box<dyn std::error::Error + Send + Sync>> { Ok(None) }
        fn list_field_rows(&self, _: i64) -> Result<Vec<PublicPlanSaveFieldDatum>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_crop_reference_rows(&self, _: i64) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveCropReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_pest_reference_rows(&self, _: i64, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSavePestReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_pesticide_reference_rows(&self, _: Option<&str>) -> Result<Vec<PublicPlanSavePesticideReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(self.rows.clone()) }
        fn list_fertilize_reference_rows(&self, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveFertilizeReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn exists_fertilize_name(&self, _: &str) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> { Ok(false) }
        fn list_agricultural_task_reference_rows(&self, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveAgriculturalTaskReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_interaction_rule_reference_rows(&self, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveInteractionRuleReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
    }

    struct MockUserPesticide {
        existing: Option<i64>,
    }

    impl PlanSaveUserPesticideGateway for MockUserPesticide {
        fn find_by_user_id_and_source_pesticide_id(&self, _: i64, _: i64) -> Result<Option<PlanSaveUserPesticideSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.existing.map(|id| PlanSaveUserPesticideSnapshot { id, name: Some("既存".into()) }))
        }
        fn create(&self, _: i64, _: crate::shared::attr::AttrMap, _: Option<crate::shared::attr::AttrMap>, _: Option<crate::shared::attr::AttrMap>) -> Result<PlanSaveUserPesticideSnapshot, Box<dyn std::error::Error + Send + Sync>> {
            Ok(PlanSaveUserPesticideSnapshot { id: 88, name: Some("農薬A".into()) })
        }
    }

    #[test]
    fn creates_user_pesticide_when_crop_and_pest_maps_resolve() {
        let row = PublicPlanSavePesticideReferenceRow::new(300, 10, 20, Some("農薬A".into()), Some("成分".into()), None, Some("jp".into()), None, None);
        let read = MockRead { rows: vec![row] };
        let mut crop_map = HashMap::new();
        crop_map.insert(10, 101);
        let mut pest_map = HashMap::new();
        pest_map.insert(20, 201);
        let logger = CapturingLogger::new();
        let out = PlanSaveEnsureUserPesticidesInteractor::new(&read, &MockUserPesticide { existing: None }, &logger, &FakeTranslator)
            .call(PlanSaveEnsureUserPesticidesInput { user_id: 1, region: Some("jp".into()), reference_crop_id_to_user_crop_id: crop_map, reference_pest_id_to_user_pest_id: pest_map })
            .unwrap();
        assert_eq!(out.user_pesticide_ids, vec![88]);
    }
}
