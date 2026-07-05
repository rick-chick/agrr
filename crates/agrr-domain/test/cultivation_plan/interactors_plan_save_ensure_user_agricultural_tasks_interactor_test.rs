// Tests for `interactors/plan_save_ensure_user_agricultural_tasks_interactor.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::dtos::{
        PlanSaveUserAgriculturalTaskSnapshot, PublicPlanSaveFieldDatum, PublicPlanSaveHeaderSnapshot,
    };
    use crate::cultivation_plan::interactors::plan_save_test_support::{
        CapturingLogger, FakeTranslator,
    };
    use crate::shared::attr::{AttrMap, AttrValue};

    struct MockRead {
        rows: Vec<PublicPlanSaveAgriculturalTaskReferenceRow>,
    }

    impl PublicPlanSaveReadGateway for MockRead {
        fn find_header(
            &self,
            _: i64,
        ) -> Result<Option<PublicPlanSaveHeaderSnapshot>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(None)
        }
        fn list_field_rows(
            &self,
            _: i64,
        ) -> Result<Vec<PublicPlanSaveFieldDatum>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }
        fn list_crop_reference_rows(
            &self,
            _: i64,
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveCropReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
        fn list_pest_reference_rows(
            &self,
            _: i64,
            _: Option<&str>,
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSavePestReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
        fn list_pesticide_reference_rows(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSavePesticideReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
        fn list_fertilize_reference_rows(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveFertilizeReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
        fn exists_fertilize_name(&self, _: &str) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
            Ok(false)
        }
        fn list_agricultural_task_reference_rows(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<PublicPlanSaveAgriculturalTaskReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(self.rows.clone())
        }
        fn list_interaction_rule_reference_rows(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveInteractionRuleReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
    }

    struct MockUserAgTask {
        existing: Option<PlanSaveUserAgriculturalTaskSnapshot>,
    }

    impl PlanSaveUserAgriculturalTaskGateway for MockUserAgTask {
        fn find_by_user_id_and_source_agricultural_task_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<PlanSaveUserAgriculturalTaskSnapshot>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(self.existing.clone())
        }
        fn create(
            &self,
            _: i64,
            attrs: AttrMap,
        ) -> Result<PlanSaveUserAgriculturalTaskSnapshot, Box<dyn std::error::Error + Send + Sync>> {
            assert_eq!(attrs.get("name"), Some(&AttrValue::from("作業A")));
            Ok(PlanSaveUserAgriculturalTaskSnapshot {
                id: 88,
                name: Some("作業A".into()),
            })
        }
    }

    fn agricultural_task_row() -> PublicPlanSaveAgriculturalTaskReferenceRow {
        PublicPlanSaveAgriculturalTaskReferenceRow {
            reference_agricultural_task_id: 300,
            name: Some("作業A".into()),
            description: None,
            time_per_sqm: Some(1.5),
            weather_dependency: None,
            required_tools: None,
            skill_level: None,
            task_type: None,
            task_type_id: None,
            region: Some("jp".into()),
            linked_reference_crop_ids: vec![10],
        }
    }

    fn default_input() -> PlanSaveEnsureUserAgriculturalTasksInput {
        let mut map = HashMap::new();
        map.insert(10, 101);
        PlanSaveEnsureUserAgriculturalTasksInput {
            user_id: 1,
            region: Some("jp".into()),
            reference_crop_id_to_user_crop_id: map,
        }
    }

    #[test]
    fn returns_empty_output_without_read_when_reference_crop_ids_empty() {
        let read = MockRead { rows: vec![] };
        let user_gw = MockUserAgTask { existing: None };
        let logger = CapturingLogger::new();
        let out = PlanSaveEnsureUserAgriculturalTasksInteractor::new(
            &read, &user_gw, &logger, &FakeTranslator,
        )
        .call(PlanSaveEnsureUserAgriculturalTasksInput {
            user_id: 1,
            region: Some("jp".into()),
            reference_crop_id_to_user_crop_id: HashMap::new(),
        })
        .unwrap();
        assert!(out.user_agricultural_task_ids.is_empty());
    }

    #[test]
    fn creates_user_agricultural_task_when_intersecting_blueprint_linked_crop() {
        let read = MockRead {
            rows: vec![agricultural_task_row()],
        };
        let user_gw = MockUserAgTask { existing: None };
        let logger = CapturingLogger::new();
        let out = PlanSaveEnsureUserAgriculturalTasksInteractor::new(
            &read, &user_gw, &logger, &FakeTranslator,
        )
        .call(default_input())
        .unwrap();
        assert_eq!(out.user_agricultural_task_ids, vec![88]);
        assert_eq!(out.reference_agricultural_task_id_to_user_task_id.get(&300), Some(&88));
    }
