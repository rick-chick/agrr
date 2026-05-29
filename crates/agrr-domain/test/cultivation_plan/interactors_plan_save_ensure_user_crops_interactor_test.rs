// Tests for `interactors/plan_save_ensure_user_crops_interactor.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::dtos::{
        PlanSaveUserCropSnapshot, PublicPlanSaveHeaderSnapshot, PublicPlanSaveFieldDatum,
    };
    use crate::cultivation_plan::interactors::plan_save_test_support::{
        CapturingLogger, FakeTranslator,
    };

    struct MockRead {
        rows: Vec<PublicPlanSaveCropReferenceRow>,
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
        ) -> Result<Vec<PublicPlanSaveCropReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(self.rows.clone())
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
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveAgriculturalTaskReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
        fn list_interaction_rule_reference_rows(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<crate::cultivation_plan::dtos::PublicPlanSaveInteractionRuleReferenceRow>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
    }

    struct MockUserCrop {
        existing: Option<i64>,
        created_id: i64,
    }

    impl PlanSaveUserCropGateway for MockUserCrop {
        fn find_by_user_id_and_source_crop_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<PlanSaveUserCropSnapshot>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.existing.map(|id| PlanSaveUserCropSnapshot { id }))
        }

        fn create(
            &self,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PlanSaveUserCropSnapshot, Box<dyn std::error::Error + Send + Sync>> {
            Ok(PlanSaveUserCropSnapshot {
                id: self.created_id,
            })
        }
    }

    struct MockCropLimit {
        count: i32,
    }

    impl PlanSaveCropLimitGateway for MockCropLimit {
        fn count_user_owned_non_reference_crops(
            &self,
            _: i64,
        ) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.count)
        }
    }

    fn reference_row() -> PublicPlanSaveCropReferenceRow {
        PublicPlanSaveCropReferenceRow {
            cultivation_plan_crop_id: 1,
            reference_crop_id: 10,
            name: Some("トマト".into()),
            variety: Some("v".into()),
            area_per_unit: Some(0.2),
            revenue_per_area: Some(1000.0),
            groups: Some(vec!["g1".into()]),
            region: Some("jp".into()),
        }
    }

    #[test]
    fn reuses_existing_user_crop_and_does_not_enqueue_stage_copy() {
        let read = MockRead {
            rows: vec![reference_row()],
        };
        let user_crop = MockUserCrop {
            existing: Some(77),
            created_id: 0,
        };
        let crop_gw = MockCropLimit { count: 0 };
        let logger = CapturingLogger::new();
        let interactor = PlanSaveEnsureUserCropsInteractor::new(
            &read, &user_crop, &crop_gw, &logger, &FakeTranslator,
        );
        let out = interactor
            .call(PlanSaveEnsureUserCropsInput {
                user_id: 1,
                plan_id: 5,
            })
            .unwrap();
        assert_eq!(out.user_crop_ids, vec![77]);
        assert_eq!(out.skipped_crop_ids, vec![77]);
        assert_eq!(out.reference_crop_id_to_user_crop_id.get(&10), Some(&77));
        assert_eq!(out.ref_cpc_id_to_user_crop_id.get(&1), Some(&77));
        assert!(out.stage_copy_pairs.is_empty());
    }

    #[test]
    fn creates_user_crop_and_returns_stage_copy_pair() {
        let read = MockRead {
            rows: vec![reference_row()],
        };
        let user_crop = MockUserCrop {
            existing: None,
            created_id: 88,
        };
        let crop_gw = MockCropLimit { count: 2 };
        let logger = CapturingLogger::new();
        let out = PlanSaveEnsureUserCropsInteractor::new(
            &read, &user_crop, &crop_gw, &logger, &FakeTranslator,
        )
        .call(PlanSaveEnsureUserCropsInput {
            user_id: 1,
            plan_id: 5,
        })
        .unwrap();
        assert_eq!(out.user_crop_ids, vec![88]);
        assert!(out.skipped_crop_ids.is_empty());
        assert_eq!(out.stage_copy_pairs.len(), 1);
        assert_eq!(out.stage_copy_pairs[0].reference_crop_id, 10);
        assert_eq!(out.stage_copy_pairs[0].new_crop_id, 88);
        let mut groups = out.reference_crop_groups;
        groups.sort();
        assert_eq!(groups, vec!["g1".to_string(), "トマト".to_string()]);
    }

    #[test]
    fn creates_user_crop_for_each_row_regardless_of_crop_region() {
        let us_row = PublicPlanSaveCropReferenceRow {
            cultivation_plan_crop_id: 2,
            reference_crop_id: 99,
            name: Some("US参照作物".into()),
            variety: Some("USV".into()),
            area_per_unit: Some(0.5),
            revenue_per_area: Some(7000.0),
            groups: Some(vec![]),
            region: Some("us".into()),
        };
        let out = PlanSaveEnsureUserCropsInteractor::new(
            &MockRead { rows: vec![us_row] },
            &MockUserCrop {
                existing: None,
                created_id: 55,
            },
            &MockCropLimit { count: 0 },
            &CapturingLogger::new(),
            &FakeTranslator,
        )
        .call(PlanSaveEnsureUserCropsInput {
            user_id: 1,
            plan_id: 5,
        })
        .unwrap();
        assert_eq!(out.user_crop_ids, vec![55]);
        assert_eq!(out.reference_crop_id_to_user_crop_id.get(&99), Some(&55));
    }

    #[test]
    fn raises_record_invalid_when_crop_limit_exceeded() {
        let err = PlanSaveEnsureUserCropsInteractor::new(
            &MockRead {
                rows: vec![reference_row()],
            },
            &MockUserCrop {
                existing: None,
                created_id: 0,
            },
            &MockCropLimit { count: 20 },
            &CapturingLogger::new(),
            &FakeTranslator,
        )
        .call(PlanSaveEnsureUserCropsInput {
            user_id: 1,
            plan_id: 5,
        })
        .unwrap_err();
        assert!(err.downcast_ref::<RecordInvalidError>().is_some());
    }
