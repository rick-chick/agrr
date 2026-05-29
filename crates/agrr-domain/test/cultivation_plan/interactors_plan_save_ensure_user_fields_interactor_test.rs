// Tests for `interactors/plan_save_ensure_user_fields_interactor.rs` (Ruby parity under test/domain/cultivation_plan/).

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
