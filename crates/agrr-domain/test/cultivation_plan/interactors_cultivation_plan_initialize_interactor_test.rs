// Tests for `interactors/cultivation_plan_initialize_interactor.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::dtos::CultivationPlanPlanCropCreateAttrs;
    use crate::cultivation_plan::entities::CultivationPlanEntity;
    use std::sync::{Arc, Mutex};

    struct FakeLogger;
    impl LoggerPort for FakeLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    struct FakeClock;
    impl ClockPort for FakeClock {
        fn today(&self) -> time::Date {
            time::macros::date!(2026-03-01)
        }
        fn now(&self) -> time::OffsetDateTime {
            time::macros::datetime!(2026-03-01 0:00 UTC)
        }
    }

    struct StubPlanGateway {
        created_id: i64,
        in_txn: Arc<Mutex<bool>>,
    }
    impl CultivationPlanGateway for StubPlanGateway {
        fn find_by_id(
            &self,
            id: i64,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(CultivationPlanEntity {
                id,
                farm_id: 1,
                user_id: 0,
                total_area: 100.0,
                plan_type: "public".into(),
                plan_year: None,
                plan_name: None,
                planning_start_date: Some("2026-01-01".into()),
                planning_end_date: Some("2026-12-31".into()),
                status: Some("draft".into()),
                session_id: None,
                display_name: Some("p".into()),
                optimization_phase: None,
                optimization_phase_message: None,
                cultivation_plan_crops_count: 0,
                cultivation_plan_fields_count: 0,
                created_at: None,
                updated_at: None,
            })
        }
        fn create(
            &self,
            _: &CultivationPlanCreateAttrs,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            self.find_by_id(self.created_id)
        }
        fn update(
            &self,
            _: i64,
            _: std::collections::HashMap<String, String>,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_by_plan_id(
            &self,
            _: i64,
        ) -> Result<Vec<crate::cultivation_plan::entities::FieldCultivationEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
        fn within_transaction<F, T>(
            &self,
            block: F,
        ) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
        where
            F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>,
        {
            *self.in_txn.lock().unwrap() = true;
            block()
        }
        fn private_owned_plan_display_name(
            &self,
            _: &crate::shared::user::User,
            _: i64,
        ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn delete(
            &self,
            _: i64,
            _: &crate::shared::user::User,
            _: &str,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyPlanCropGateway {
        created: Arc<Mutex<bool>>,
    }
    impl CultivationPlanPlanCropGateway for SpyPlanCropGateway {
        fn create_for_plan(
            &self,
            _: &CultivationPlanPlanCropCreateAttrs,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            *self.created.lock().unwrap() = true;
            Ok(())
        }
        fn create(
            &self,
            _: i64,
            _: &crate::crop::dtos::AddCropCropSnapshot,
        ) -> Result<crate::cultivation_plan::dtos::CultivationPlanCropSnapshot, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn delete(&self, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyFieldMutationGateway {
        create_count: Arc<Mutex<usize>>,
    }
    impl CultivationPlanFieldMutationGateway for SpyFieldMutationGateway {
        fn count_fields(&self, _: i64) -> Result<i32, Box<dyn std::error::Error + Send + Sync>> {
            Ok(0)
        }
        fn find_field(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<crate::cultivation_plan::dtos::CultivationPlanFieldSnapshot>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(None)
        }
        fn create_field(
            &self,
            _: i64,
            _: &str,
            _: f64,
            _: Option<f64>,
        ) -> Result<crate::cultivation_plan::dtos::CultivationPlanFieldSnapshot, Box<dyn std::error::Error + Send + Sync>>
        {
            *self.create_count.lock().unwrap() += 1;
            Ok(crate::cultivation_plan::dtos::CultivationPlanFieldSnapshot::new(1, "1", 1.0))
        }
        fn delete_field(&self, _: i64, _: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
        fn refresh_total_area(&self, _: i64) -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
            Ok(0.0)
        }
    }

    #[test]
    fn returns_failure_when_total_area_is_not_positive() {
        let plan_gateway = StubPlanGateway {
            created_id: 99,
            in_txn: Arc::new(Mutex::new(false)),
        };
        let plan_crop_gateway = SpyPlanCropGateway {
            created: Arc::new(Mutex::new(false)),
        };
        let field_gateway = SpyFieldMutationGateway {
            create_count: Arc::new(Mutex::new(0)),
        };
        let clock = FakeClock;
        let logger = FakeLogger;
        let interactor = CultivationPlanInitializeInteractor::new(
            CultivationPlanInitFarm {
                id: 1,
                name: "Farm".into(),
            },
            0.0,
            vec![CultivationPlanInitCrop {
                id: 10,
                name: "Crop".into(),
                variety: Some("V".into()),
                area_per_unit: 1.0,
                revenue_per_area: 100.0,
            }],
            &plan_gateway,
            &plan_crop_gateway,
            &field_gateway,
            &clock,
            &logger,
        );

        let result = interactor.call().unwrap();
        assert!(!result.is_success());
        assert!(result.errors[0].contains("総面積"));
    }

    #[test]
    fn creates_plan_crops_and_fields_inside_transaction_when_valid() {
        let in_txn = Arc::new(Mutex::new(false));
        let crop_created = Arc::new(Mutex::new(false));
        let field_count = Arc::new(Mutex::new(0));
        let plan_gateway = StubPlanGateway {
            created_id: 99,
            in_txn: Arc::clone(&in_txn),
        };
        let plan_crop_gateway = SpyPlanCropGateway {
            created: Arc::clone(&crop_created),
        };
        let field_gateway = SpyFieldMutationGateway {
            create_count: Arc::clone(&field_count),
        };
        let clock = FakeClock;
        let logger = FakeLogger;
        let interactor = CultivationPlanInitializeInteractor::new(
            CultivationPlanInitFarm {
                id: 1,
                name: "Farm".into(),
            },
            100.0,
            vec![CultivationPlanInitCrop {
                id: 10,
                name: "Crop".into(),
                variety: Some("V".into()),
                area_per_unit: 1.0,
                revenue_per_area: 100.0,
            }],
            &plan_gateway,
            &plan_crop_gateway,
            &field_gateway,
            &clock,
            &logger,
        );

        let result = interactor.call().unwrap();
        assert!(result.is_success());
        assert_eq!(result.cultivation_plan.unwrap().id, 99);
        assert!(*in_txn.lock().unwrap());
        assert!(*crop_created.lock().unwrap());
        assert!(*field_count.lock().unwrap() >= 1);
    }
