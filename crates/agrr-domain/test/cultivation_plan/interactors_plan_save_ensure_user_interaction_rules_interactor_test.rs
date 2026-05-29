// Tests for `interactors/plan_save_ensure_user_interaction_rules_interactor.rs` (Ruby parity under test/domain/cultivation_plan/).

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
