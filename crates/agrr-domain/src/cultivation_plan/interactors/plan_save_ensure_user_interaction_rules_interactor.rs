//! Ruby: `Domain::CultivationPlan::Interactors::PlanSaveEnsureUserInteractionRulesInteractor`

use std::collections::BTreeMap;

use crate::cultivation_plan::dtos::{
    PlanSaveEnsureUserInteractionRulesInput, PlanSaveEnsureUserInteractionRulesOutput,
    PlanSaveUserInteractionRuleSnapshot, PublicPlanSaveInteractionRuleReferenceRow,
};
use crate::cultivation_plan::gateways::{
    PlanSaveUserInteractionRuleGateway, PublicPlanSaveReadGateway,
};
use crate::cultivation_plan::helpers::attr_map_from_json;
use crate::cultivation_plan::mappers::interaction_rule_attributes_for_create;
use crate::shared::attr::{attr_map_from_pairs, AttrValue};
use crate::shared::ports::{LoggerPort, TranslatorPort};

pub struct PlanSaveEnsureUserInteractionRulesInteractor<'a, R, U, L, T> {
    read_gateway: &'a R,
    user_interaction_rule_gateway: &'a U,
    logger: &'a L,
    translator: &'a T,
}

impl<'a, R, U, L, T> PlanSaveEnsureUserInteractionRulesInteractor<'a, R, U, L, T>
where
    R: PublicPlanSaveReadGateway,
    U: PlanSaveUserInteractionRuleGateway,
    L: LoggerPort,
    T: TranslatorPort,
{
    pub fn new(
        read_gateway: &'a R,
        user_interaction_rule_gateway: &'a U,
        logger: &'a L,
        translator: &'a T,
    ) -> Self {
        Self {
            read_gateway,
            user_interaction_rule_gateway,
            logger,
            translator,
        }
    }

    pub fn call(
        &self,
        input: PlanSaveEnsureUserInteractionRulesInput,
    ) -> Result<PlanSaveEnsureUserInteractionRulesOutput, Box<dyn std::error::Error + Send + Sync>>
    {
        if input.reference_crop_groups.is_empty() {
            return Ok(PlanSaveEnsureUserInteractionRulesOutput {
                user_interaction_rule_ids: vec![],
                skipped_interaction_rule_ids: vec![],
            });
        }

        let rows = self
            .read_gateway
            .list_interaction_rule_reference_rows(input.region.as_deref())?;
        let crop_groups = &input.reference_crop_groups;

        let mut user_interaction_rule_ids = Vec::new();
        let mut skipped_interaction_rule_ids = Vec::new();

        for row in rows {
            if !row_matches_plan_crop_groups(&row, crop_groups) {
                continue;
            }

            if let Some(existing) = self.find_existing_rule(input.user_id, &row)? {
                self.link_source_if_needed(input.user_id, &existing, &row)?;
                skipped_interaction_rule_ids.push(existing.id);
                user_interaction_rule_ids.push(existing.id);
                continue;
            }

            let attributes = attr_map_from_json(interaction_rule_attributes_for_create(&row));
            let created = self
                .user_interaction_rule_gateway
                .create(input.user_id, attributes)?;

            user_interaction_rule_ids.push(created.id);
            self.logger.info(&self.translator.t(
                "services.plan_save_service.messages.interaction_rule_created",
                &BTreeMap::from([
                    ("source_group".into(), row.source_group.clone()),
                    ("target_group".into(), row.target_group.clone()),
                ]),
            ));
        }

        Ok(PlanSaveEnsureUserInteractionRulesOutput {
            user_interaction_rule_ids,
            skipped_interaction_rule_ids,
        })
    }

    fn find_existing_rule(
        &self,
        user_id: i64,
        row: &PublicPlanSaveInteractionRuleReferenceRow,
    ) -> Result<Option<PlanSaveUserInteractionRuleSnapshot>, Box<dyn std::error::Error + Send + Sync>>
    {
        if let Some(by_source) = self
            .user_interaction_rule_gateway
            .find_by_user_id_and_source_interaction_rule_id(
                user_id,
                row.reference_interaction_rule_id,
            )?
        {
            return Ok(Some(by_source));
        }
        self.user_interaction_rule_gateway
            .find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region(
                user_id,
                &row.rule_type,
                &row.source_group,
                &row.target_group,
                row.region.as_deref(),
            )
    }

    fn link_source_if_needed(
        &self,
        user_id: i64,
        existing: &PlanSaveUserInteractionRuleSnapshot,
        row: &PublicPlanSaveInteractionRuleReferenceRow,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if existing.source_interaction_rule_id.is_some() {
            return Ok(());
        }
        let attrs = attr_map_from_pairs([(
            "source_interaction_rule_id",
            AttrValue::Int(row.reference_interaction_rule_id),
        )]);
        self.user_interaction_rule_gateway
            .update(user_id, existing.id, attrs)?;
        Ok(())
    }
}

fn row_matches_plan_crop_groups(
    row: &PublicPlanSaveInteractionRuleReferenceRow,
    crop_groups: &[String],
) -> bool {
    crop_groups.contains(&row.source_group) || crop_groups.contains(&row.target_group)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cultivation_plan::dtos::{PublicPlanSaveFieldDatum, PublicPlanSaveHeaderSnapshot};
    use crate::cultivation_plan::interactors::plan_save_test_support::{
        CapturingLogger, FakeTranslator,
    };

    struct MockRead {
        rows: Vec<PublicPlanSaveInteractionRuleReferenceRow>,
    }

    impl PublicPlanSaveReadGateway for MockRead {
        fn find_header(&self, _: i64) -> Result<Option<PublicPlanSaveHeaderSnapshot>, Box<dyn std::error::Error + Send + Sync>> { Ok(None) }
        fn list_field_rows(&self, _: i64) -> Result<Vec<PublicPlanSaveFieldDatum>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_crop_reference_rows(&self, _: i64) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveCropReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_pest_reference_rows(&self, _: i64, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSavePestReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_pesticide_reference_rows(&self, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSavePesticideReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_fertilize_reference_rows(&self, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveFertilizeReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn exists_fertilize_name(&self, _: &str) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> { Ok(false) }
        fn list_agricultural_task_reference_rows(&self, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveAgriculturalTaskReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_interaction_rule_reference_rows(&self, _: Option<&str>) -> Result<Vec<PublicPlanSaveInteractionRuleReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(self.rows.clone()) }
    }

    struct MockUserRule;

    impl PlanSaveUserInteractionRuleGateway for MockUserRule {
        fn find_by_user_id_and_source_interaction_rule_id(&self, _: i64, _: i64) -> Result<Option<PlanSaveUserInteractionRuleSnapshot>, Box<dyn std::error::Error + Send + Sync>> { Ok(None) }
        fn find_by_user_id_and_rule_type_and_source_group_and_target_group_and_region(&self, _: i64, _: &str, _: &str, _: &str, _: Option<&str>) -> Result<Option<PlanSaveUserInteractionRuleSnapshot>, Box<dyn std::error::Error + Send + Sync>> { Ok(None) }
        fn update(&self, _: i64, _: i64, _: crate::shared::attr::AttrMap) -> Result<PlanSaveUserInteractionRuleSnapshot, Box<dyn std::error::Error + Send + Sync>> { unimplemented!() }
        fn create(&self, _: i64, _: crate::shared::attr::AttrMap) -> Result<PlanSaveUserInteractionRuleSnapshot, Box<dyn std::error::Error + Send + Sync>> {
            Ok(PlanSaveUserInteractionRuleSnapshot { id: 55, source_interaction_rule_id: Some(100) })
        }
    }

    #[test]
    fn returns_empty_output_when_reference_crop_groups_empty() {
        let read = MockRead { rows: vec![] };
        let logger = CapturingLogger::new();
        let out = PlanSaveEnsureUserInteractionRulesInteractor::new(&read, &MockUserRule, &logger, &FakeTranslator)
            .call(PlanSaveEnsureUserInteractionRulesInput { user_id: 1, region: Some("jp".into()), reference_crop_groups: vec![] })
            .unwrap();
        assert!(out.user_interaction_rule_ids.is_empty());
    }

    #[test]
    fn creates_user_interaction_rule_when_no_existing_match() {
        let row = PublicPlanSaveInteractionRuleReferenceRow::new(100, "continuous_cultivation", "GroupA", "GroupB", 0.5, true, Some("jp".into()), Some("desc".into()));
        let read = MockRead { rows: vec![row] };
        let logger = CapturingLogger::new();
        let out = PlanSaveEnsureUserInteractionRulesInteractor::new(&read, &MockUserRule, &logger, &FakeTranslator)
            .call(PlanSaveEnsureUserInteractionRulesInput { user_id: 1, region: Some("jp".into()), reference_crop_groups: vec!["GroupA".into(), "GroupB".into()] })
            .unwrap();
        assert_eq!(out.user_interaction_rule_ids, vec![55]);
    }
}
