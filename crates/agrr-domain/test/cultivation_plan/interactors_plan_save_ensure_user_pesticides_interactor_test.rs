// Tests for `interactors/plan_save_ensure_user_pesticides_interactor.rs` (Ruby parity under test/domain/cultivation_plan/).

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
