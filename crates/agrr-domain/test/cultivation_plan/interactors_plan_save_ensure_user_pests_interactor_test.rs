// Tests for `interactors/plan_save_ensure_user_pests_interactor.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::dtos::{
        PlanSaveUserPestSnapshot, PublicPlanSaveFieldDatum, PublicPlanSaveHeaderSnapshot,
    };
    use crate::cultivation_plan::interactors::plan_save_test_support::{
        CapturingLogger, FakeTranslator,
    };

    struct MockRead {
        rows: Vec<PublicPlanSavePestReferenceRow>,
    }

    impl PublicPlanSaveReadGateway for MockRead {
        fn find_header(&self, _: i64) -> Result<Option<PublicPlanSaveHeaderSnapshot>, Box<dyn std::error::Error + Send + Sync>> { Ok(None) }
        fn list_field_rows(&self, _: i64) -> Result<Vec<PublicPlanSaveFieldDatum>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_crop_reference_rows(&self, _: i64) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveCropReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_pest_reference_rows(&self, _: i64, _: Option<&str>) -> Result<Vec<PublicPlanSavePestReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(self.rows.clone()) }
        fn list_pesticide_reference_rows(&self, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSavePesticideReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_fertilize_reference_rows(&self, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveFertilizeReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn exists_fertilize_name(&self, _: &str) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> { Ok(false) }
        fn list_agricultural_task_reference_rows(&self, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveAgriculturalTaskReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
        fn list_interaction_rule_reference_rows(&self, _: Option<&str>) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveInteractionRuleReferenceRow>, Box<dyn std::error::Error + Send + Sync>> { Ok(vec![]) }
    }

    struct MockUserPest {
        existing: Option<i64>,
    }

    impl PlanSaveUserPestGateway for MockUserPest {
        fn find_by_user_id_and_source_pest_id(&self, _: i64, _: i64) -> Result<Option<PlanSaveUserPestSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.existing.map(|id| PlanSaveUserPestSnapshot { id, name: Some("害虫A".into()) }))
        }
        fn create(&self, _: i64, _: crate::shared::attr::AttrMap) -> Result<PlanSaveUserPestSnapshot, Box<dyn std::error::Error + Send + Sync>> {
            Ok(PlanSaveUserPestSnapshot { id: 66, name: Some("害虫B".into()) })
        }
        fn create_temperature_profile(&self, _: i64, _: crate::shared::attr::AttrMap) {}
        fn create_thermal_requirement(&self, _: i64, _: crate::shared::attr::AttrMap) {}
        fn create_control_method(&self, _: i64, _: crate::shared::attr::AttrMap) {}
        fn link_crop_pest(&self, _: i64, _: i64) {}
    }

    fn pest_row() -> PublicPlanSavePestReferenceRow {
        PublicPlanSavePestReferenceRow {
            reference_pest_id: 100,
            name: Some("害虫A".into()),
            name_scientific: None,
            family: None,
            order: None,
            description: None,
            occurrence_season: None,
            region: Some("jp".into()),
            linked_reference_crop_ids: vec![10],
            temperature_profile: None,
            thermal_requirement: None,
            control_methods: vec![],
        }
    }

    #[test]
    fn returns_empty_output_when_reference_crop_map_is_empty() {
        let read = MockRead { rows: vec![] };
        let logger = CapturingLogger::new();
        let out = PlanSaveEnsureUserPestsInteractor::new(&read, &MockUserPest { existing: None }, &logger, &FakeTranslator)
            .call(PlanSaveEnsureUserPestsInput { user_id: 1, plan_id: 5, region: Some("jp".into()), reference_crop_id_to_user_crop_id: HashMap::new() })
            .unwrap();
        assert!(out.user_pest_ids.is_empty());
    }

    #[test]
    fn reuses_existing_user_pest_and_links_crops() {
        let read = MockRead { rows: vec![pest_row()] };
        let mut map = HashMap::new();
        map.insert(10, 77);
        let logger = CapturingLogger::new();
        let out = PlanSaveEnsureUserPestsInteractor::new(&read, &MockUserPest { existing: Some(55) }, &logger, &FakeTranslator)
            .call(PlanSaveEnsureUserPestsInput { user_id: 1, plan_id: 5, region: Some("jp".into()), reference_crop_id_to_user_crop_id: map })
            .unwrap();
        assert_eq!(out.user_pest_ids, vec![55]);
        assert_eq!(out.skipped_pest_ids, vec![55]);
    }
