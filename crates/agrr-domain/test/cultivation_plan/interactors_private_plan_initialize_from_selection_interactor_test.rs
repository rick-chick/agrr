// Tests for `interactors/private_plan_initialize_from_selection_interactor.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::dtos::CultivationPlanInitializeResult;
    use crate::cultivation_plan::entities::CultivationPlanEntity;
    use crate::farm::entities::FarmEntity;
    use crate::shared::ports::translator_port::TranslateOptions;
    use crate::shared::user::User;
    use std::sync::{Arc, Mutex};
    use time::macros::date;

    struct FakeTranslator;
    impl TranslatorPort for FakeTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            key.to_string()
        }
        fn localize(&self, _: Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct FakeLogger;
    impl LoggerPort for FakeLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    struct FakeClock;
    impl ClockPort for FakeClock {
        fn today(&self) -> Date {
            date!(2026-06-15)
        }
        fn now(&self) -> time::OffsetDateTime {
            time::macros::datetime!(2026-06-15 12:00 UTC)
        }
    }

    struct SpyOutput {
        success: Arc<Mutex<Vec<i64>>>,
        failures: Arc<Mutex<Vec<PrivatePlanInitializeFromSelectionFailure>>>,
    }

    impl PrivatePlanInitializeFromSelectionOutputPort for SpyOutput {
        fn on_success(&mut self, dto: PrivatePlanInitializeFromSelectionOutput) {
            self.success.lock().unwrap().push(dto.id);
        }
        fn on_failure(&mut self, failure: PrivatePlanInitializeFromSelectionFailure) {
            self.failures.lock().unwrap().push(failure);
        }
    }

    struct StubExistingGateway {
        existing: Option<CultivationPlanEntity>,
    }
    impl PrivatePlanExistingPlanGateway for StubExistingGateway {
        fn find_existing(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<CultivationPlanEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.existing.clone())
        }
    }

    struct StubFarmGateway {
        farm: Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>>,
    }
    impl PrivatePlanFarmResolveGateway for StubFarmGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FarmEntity, Box<dyn std::error::Error + Send + Sync>> {
            match &self.farm {
                Ok(f) => Ok(f.clone()),
                Err(_e) => Err(Box::new(RecordNotFoundError) as _),
            }
        }
    }

    struct StubCropGateway {
        crops: Vec<CropEntity>,
    }
    impl PrivatePlanCropListGateway for StubCropGateway {
        fn list_by_ids(
            &self,
            _: &[i64],
        ) -> Result<Vec<CropEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.crops.clone())
        }
    }

    struct StubFieldGateway {
        total_area: f64,
    }
    impl FieldGateway for StubFieldGateway {
        fn get_total_area_by_farm_id(&self, _: i64) -> Result<f64, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.total_area)
        }
        fn farm_fields_list(
            &self,
            _: i64,
        ) -> Result<crate::field::results::FarmFieldsList, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn field_with_farm(
            &self,
            _: i64,
        ) -> Result<crate::field::results::FieldWithFarm, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create(
            &self,
            _: &crate::field::dtos::FieldCreateInput,
            _: i64,
            _: &crate::shared::reference_record_access_filter::ReferenceRecordAccessFilter<
                crate::shared::policies::farm_policy::FarmRecordAccessPolicy,
            >,
        ) -> Result<crate::field::entities::FieldEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update(
            &self,
            _: i64,
            _: &crate::field::dtos::FieldUpdateInput,
        ) -> Result<crate::field::entities::FieldEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn delete(&self, _: i64) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct StubInitializer {
        result: CultivationPlanInitializeResult,
    }
    impl PrivatePlanInitializeCallablePort for StubInitializer {
        fn call(
            &self,
            _: &CultivationPlanInitFarm,
            _: f64,
            _: &[CultivationPlanInitCrop],
            _: i64,
            _: &str,
            _: &str,
            _: Date,
            _: Date,
        ) -> Result<CultivationPlanInitializeResult, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.result.clone())
        }
    }

    struct StubSessionGen;
    impl PrivatePlanSessionIdGeneratorPort for StubSessionGen {
        fn generate(&self) -> String {
            "sessionhex".into()
        }
    }

    struct SpyJobChain {
        enqueued: Arc<Mutex<Vec<i64>>>,
        fail: bool,
    }
    impl PrivatePlanOptimizationJobChainGateway for SpyJobChain {
        fn enqueue_after_create(
            &self,
            plan_id: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            if self.fail {
                return Err("queue down".into());
            }
            self.enqueued.lock().unwrap().push(plan_id);
            Ok(())
        }
    }

    fn user(id: i64) -> User {
        User::new(id, false)
    }

    fn owned_farm(user_id: i64) -> FarmEntity {
        FarmEntity {
            id: 1,
            name: "F".into(),
            latitude: Some(35.0),
            longitude: Some(139.0),
            region: Some("jp".into()),
            user_id: Some(user_id),
            is_reference: false,
            created_at: None,
            updated_at: None,
            weather_data_status: None,
            weather_data_fetched_years: None,
            weather_data_total_years: None,
            weather_data_last_error: None,
            weather_location_id: None,
            last_broadcast_at: None,
        }
    }

    fn owned_crop(user_id: i64) -> CropEntity {
        CropEntity {
            id: 10,
            user_id: Some(user_id),
            name: "C".into(),
            variety: Some("V".into()),
            is_reference: false,
            area_per_unit: Some(1.0),
            revenue_per_area: Some(1.0),
            region: Some("jp".into()),
            groups: vec![],
            created_at: None,
            updated_at: None,
        }
    }

    fn plan_entity(id: i64, user_id: i64) -> CultivationPlanEntity {
        CultivationPlanEntity {
            id,
            farm_id: 1,
            user_id,
            total_area: 1.0,
            plan_type: "private".into(),
            plan_year: None,
            plan_name: Some("P".into()),
            planning_start_date: Some("2026-01-01".into()),
            planning_end_date: Some("2027-12-31".into()),
            status: Some("draft".into()),
            session_id: Some("sessionhex".into()),
            display_name: Some("P".into()),
            optimization_phase: None,
            optimization_phase_message: None,
            cultivation_plan_crops_count: 1,
            cultivation_plan_fields_count: 1,
            created_at: None,
            updated_at: None,
        }
    }

    #[test]
    fn on_failure_unprocessable_when_crop_ids_empty() {
        let success = Arc::new(Mutex::new(Vec::new()));
        let failures = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failures: Arc::clone(&failures),
        };
        let session_gen = StubSessionGen;
        let job_chain = SpyJobChain {
            enqueued: Arc::new(Mutex::new(Vec::new())),
            fail: false,
        };
        let existing_gateway = StubExistingGateway { existing: None };
        let farm_gateway = StubFarmGateway {
            farm: Ok(owned_farm(1)),
        };
        let crop_gateway = StubCropGateway {
            crops: vec![owned_crop(1)],
        };
        let field_gateway = StubFieldGateway { total_area: 10.0 };
        let initializer = StubInitializer {
            result: CultivationPlanInitializeResult::success(plan_entity(42, 1)),
        };
        let logger = FakeLogger;
        let translator = FakeTranslator;
        let clock = FakeClock;
        let mut interactor = PrivatePlanInitializeFromSelectionInteractor::new(
            &mut output,
            &existing_gateway,
            &farm_gateway,
            &crop_gateway,
            &field_gateway,
            &initializer,
            &logger,
            &translator,
            &clock,
            &session_gen,
            &job_chain,
        );

        let input = PrivatePlanInitializeFromSelectionInput {
            farm_id: 1,
            crop_ids: vec![],
            user: user(1),
            plan_name: None,
        };
        interactor.call(&input).unwrap();

        let f = failures.lock().unwrap();
        assert_eq!(f.len(), 1);
        assert_eq!(
            f[0].http_status,
            PrivatePlanInitializeFromSelectionFailure::HTTP_UNPROCESSABLE_ENTITY
        );
        assert_eq!(f[0].message, "plans.errors.select_crop");
        assert!(success.lock().unwrap().is_empty());
    }

    #[test]
    fn on_success_enqueues_jobs_and_returns_id() {
        let success = Arc::new(Mutex::new(Vec::new()));
        let failures = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failures: Arc::clone(&failures),
        };
        let enqueued = Arc::new(Mutex::new(Vec::new()));
        let session_gen = StubSessionGen;
        let job_chain = SpyJobChain {
            enqueued: Arc::clone(&enqueued),
            fail: false,
        };
        let existing_gateway = StubExistingGateway { existing: None };
        let farm_gateway = StubFarmGateway {
            farm: Ok(owned_farm(1)),
        };
        let crop_gateway = StubCropGateway {
            crops: vec![owned_crop(1)],
        };
        let field_gateway = StubFieldGateway { total_area: 100.0 };
        let initializer = StubInitializer {
            result: CultivationPlanInitializeResult::success(plan_entity(42, 1)),
        };
        let logger = FakeLogger;
        let translator = FakeTranslator;
        let clock = FakeClock;
        let mut interactor = PrivatePlanInitializeFromSelectionInteractor::new(
            &mut output,
            &existing_gateway,
            &farm_gateway,
            &crop_gateway,
            &field_gateway,
            &initializer,
            &logger,
            &translator,
            &clock,
            &session_gen,
            &job_chain,
        );

        let input = PrivatePlanInitializeFromSelectionInput {
            farm_id: 1,
            crop_ids: vec![10],
            user: user(1),
            plan_name: Some("P".into()),
        };
        interactor.call(&input).unwrap();

        assert_eq!(*success.lock().unwrap(), vec![42]);
        assert_eq!(*enqueued.lock().unwrap(), vec![42]);
        assert!(failures.lock().unwrap().is_empty());
    }

    #[test]
    fn enqueue_after_create_error_propagates() {
        let success = Arc::new(Mutex::new(Vec::new()));
        let failures = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failures: Arc::clone(&failures),
        };
        let session_gen = StubSessionGen;
        let job_chain = SpyJobChain {
            enqueued: Arc::new(Mutex::new(Vec::new())),
            fail: true,
        };
        let existing_gateway = StubExistingGateway { existing: None };
        let farm_gateway = StubFarmGateway {
            farm: Ok(owned_farm(1)),
        };
        let crop_gateway = StubCropGateway {
            crops: vec![owned_crop(1)],
        };
        let field_gateway = StubFieldGateway { total_area: 10.0 };
        let initializer = StubInitializer {
            result: CultivationPlanInitializeResult::success(plan_entity(42, 1)),
        };
        let logger = FakeLogger;
        let translator = FakeTranslator;
        let clock = FakeClock;
        let mut interactor = PrivatePlanInitializeFromSelectionInteractor::new(
            &mut output,
            &existing_gateway,
            &farm_gateway,
            &crop_gateway,
            &field_gateway,
            &initializer,
            &logger,
            &translator,
            &clock,
            &session_gen,
            &job_chain,
        );

        let input = PrivatePlanInitializeFromSelectionInput {
            farm_id: 1,
            crop_ids: vec![10],
            user: user(1),
            plan_name: None,
        };
        let err = interactor.call(&input).unwrap_err();
        assert!(err.to_string().contains("queue down"));
        assert!(success.lock().unwrap().is_empty());
    }
