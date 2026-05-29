// Tests for `interactors/plan_allocation_adjust_interactor.rs` (Ruby parity under test/domain/cultivation_plan/).

    use crate::cultivation_plan::dtos::{
        CultivationPlanRestAuth, PlanAllocationAdjustPlanCropSnapshot,
        PlanAllocationAdjustReadSnapshot,
    };
    use crate::cultivation_plan::entities::CultivationPlanEntity;
    use crate::cultivation_plan::gateways::PlanAllocationAdjustDebugDumpNullGateway;
    use crate::shared::ports::translator_port::TranslateOptions;
    use serde_json::json;
    use std::sync::{Arc, Mutex};
    use time::macros::datetime;

    struct FakeTranslator;
    impl TranslatorPort for FakeTranslator {
        fn translate(&self, key: &str, options: &TranslateOptions) -> String {
            let mut parts = vec![key.to_string()];
            for (k, v) in options {
                parts.push(format!("{k}={v}"));
            }
            parts.join(":")
        }

        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct FakeLogger {
        entries: Arc<Mutex<Vec<String>>>,
    }

    impl LoggerPort for FakeLogger {
        fn info(&self, message: &str) {
            self.entries.lock().unwrap().push(message.to_string());
        }
        fn warn(&self, message: &str) {
            self.info(message);
        }
        fn error(&self, message: &str) {
            self.info(message);
        }
        fn debug(&self, message: &str) {
            self.info(message);
        }
    }

    struct FakeClock;
    impl ClockPort for FakeClock {
        fn today(&self) -> time::Date {
            time::macros::date!(2026-01-01)
        }
        fn now(&self) -> time::OffsetDateTime {
            datetime!(2026-01-01 12:00 UTC)
        }
    }

    struct SpyOutput {
        success: Arc<Mutex<Vec<PlanAllocationAdjustOutput>>>,
        failures: Arc<Mutex<Vec<PlanAllocationAdjustFailure>>>,
    }

    impl PlanAllocationAdjustOutputPort for SpyOutput {
        fn on_success(&mut self, output: PlanAllocationAdjustOutput) {
            self.success.lock().unwrap().push(output);
        }
        fn on_failure(&mut self, failure: PlanAllocationAdjustFailure) {
            self.failures.lock().unwrap().push(failure);
        }
    }

    fn owned_plan() -> CultivationPlanEntity {
        CultivationPlanEntity {
            id: 2,
            farm_id: 1,
            user_id: 1,
            total_area: 0.0,
            plan_type: "private".into(),
            plan_year: None,
            plan_name: None,
            planning_start_date: None,
            planning_end_date: None,
            status: None,
            session_id: None,
            display_name: None,
            optimization_phase: None,
            optimization_phase_message: None,
            cultivation_plan_crops_count: 0,
            cultivation_plan_fields_count: 0,
            created_at: None,
            updated_at: None,
        }
    }

    fn other_users_plan() -> CultivationPlanEntity {
        let mut plan = owned_plan();
        plan.user_id = 99;
        plan
    }

    fn snapshot(crop_name: &str, has_growth_stages: bool) -> PlanAllocationAdjustReadSnapshot {
        PlanAllocationAdjustReadSnapshot::minimal_for_tests(2, crop_name, has_growth_stages)
    }

    struct StubPlanGateway {
        plan: CultivationPlanEntity,
    }

    impl CultivationPlanGateway for StubPlanGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.plan.clone())
        }
        fn create(
            &self,
            _: &crate::cultivation_plan::dtos::CultivationPlanCreateAttrs,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
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
            unimplemented!()
        }
        fn within_transaction<F, T>(
            &self,
            block: F,
        ) -> Result<T, Box<dyn std::error::Error + Send + Sync>>
        where
            F: FnOnce() -> Result<T, Box<dyn std::error::Error + Send + Sync>>,
        {
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

    struct StubReadGateway {
        snapshot: PlanAllocationAdjustReadSnapshot,
        called: Arc<Mutex<bool>>,
    }

    impl PlanAllocationAdjustReadGateway for StubReadGateway {
        fn find_adjust_read_snapshot_by_plan_id(
            &self,
            _: i64,
        ) -> Result<PlanAllocationAdjustReadSnapshot, Box<dyn std::error::Error + Send + Sync>>
        {
            *self.called.lock().unwrap() = true;
            Ok(self.snapshot.clone())
        }
        fn list_historical_weather_rows(
            &self,
            _: Option<i64>,
            _: time::Date,
            _: time::Date,
        ) -> Result<Vec<serde_json::Value>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn plan_summary_for_adjust_response(
            &self,
            _: i64,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct StubAdjustGateway;
    impl PlanAllocationAdjustGateway for StubAdjustGateway {
        fn adjust(
            &self,
            _: &serde_json::Value,
            _: &[serde_json::Value],
            _: &[serde_json::Value],
            _: &[serde_json::Value],
            _: &serde_json::Value,
            _: time::Date,
            _: time::Date,
            _: Option<&serde_json::Value>,
            _: &str,
            _: Option<i64>,
            _: bool,
        ) -> Result<serde_json::Value, crate::cultivation_plan::errors::AdjustExecutionError>
        {
            unimplemented!()
        }
    }

    struct StubEventsGateway;
    impl CultivationPlanOptimizationEventsGateway for StubEventsGateway {
        fn broadcast_field_added(
            &self,
            _: i64,
            _: &str,
            _: &crate::cultivation_plan::dtos::CultivationPlanFieldSnapshot,
            _: f64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }

        fn broadcast_field_removed(
            &self,
            _: i64,
            _: &str,
            _: i64,
            _: f64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }

        fn broadcast_optimization_complete(
            &self,
            _: i64,
            _: &str,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    // Ruby: test "call loads adjust read snapshot after RestPlanAccess for private auth"
    #[test]
    fn call_loads_adjust_read_snapshot_after_rest_plan_access_for_private_auth() {
        let success = Arc::new(Mutex::new(Vec::new()));
        let failures = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failures: Arc::clone(&failures),
        };
        let read_called = Arc::new(Mutex::new(false));
        let logger = FakeLogger {
            entries: Arc::new(Mutex::new(Vec::new())),
        };
        let plan_gateway = StubPlanGateway {
            plan: owned_plan(),
        };
        let read_gateway = StubReadGateway {
            snapshot: snapshot("C", true),
            called: Arc::clone(&read_called),
        };
        let events_gateway = StubEventsGateway;
        let mut interactor = PlanAllocationAdjustInteractor::new(
            &mut output,
            &logger,
            &FakeTranslator,
            &FakeClock,
            &plan_gateway,
            &read_gateway,
            &StubAdjustGateway,
            &events_gateway,
            &PlanAllocationAdjustDebugDumpNullGateway,
            "abcd1234",
        );

        interactor
            .call(PlanAllocationAdjustInput {
                plan_id: 2,
                moves: vec![],
                auth: Some(CultivationPlanRestAuth::private(1)),
            })
            .unwrap();

        assert!(*read_called.lock().unwrap());
        let successes = success.lock().unwrap();
        assert_eq!(successes.len(), 1);
        assert!(successes[0].skipped);
        assert!(successes[0].message.contains("調整不要"));
        assert!(failures.lock().unwrap().is_empty());
    }

    // Ruby: test "call dispatches not_found when private auth and plan owned by another user"
    #[test]
    fn call_dispatches_not_found_when_private_auth_and_plan_owned_by_another_user() {
        let success = Arc::new(Mutex::new(Vec::new()));
        let failures = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failures: Arc::clone(&failures),
        };
        let read_called = Arc::new(Mutex::new(false));
        let logger = FakeLogger {
            entries: Arc::new(Mutex::new(Vec::new())),
        };
        let plan_gateway = StubPlanGateway {
            plan: other_users_plan(),
        };
        let read_gateway = StubReadGateway {
            snapshot: snapshot("C", true),
            called: Arc::clone(&read_called),
        };
        let events_gateway = StubEventsGateway;
        let mut interactor = PlanAllocationAdjustInteractor::new(
            &mut output,
            &logger,
            &FakeTranslator,
            &FakeClock,
            &plan_gateway,
            &read_gateway,
            &StubAdjustGateway,
            &events_gateway,
            &PlanAllocationAdjustDebugDumpNullGateway,
            "abcd1234",
        );

        interactor
            .call(PlanAllocationAdjustInput {
                plan_id: 2,
                moves: vec![],
                auth: Some(CultivationPlanRestAuth::private(1)),
            })
            .unwrap();

        assert!(!*read_called.lock().unwrap());
        assert!(success.lock().unwrap().is_empty());
        let failure = failures.lock().unwrap();
        assert_eq!(failure.len(), 1);
        assert_eq!(failure[0].kind, PlanAllocationAdjustFailure::KIND_NOT_FOUND);
    }

    // Ruby: test "call dispatches crop_missing_growth_stages when plan crop has no growth stages"
    #[test]
    fn call_dispatches_crop_missing_growth_stages_when_plan_crop_has_no_growth_stages() {
        let success = Arc::new(Mutex::new(Vec::new()));
        let failures = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            success: Arc::clone(&success),
            failures: Arc::clone(&failures),
        };
        let logger = FakeLogger {
            entries: Arc::new(Mutex::new(Vec::new())),
        };
        let plan_gateway = StubPlanGateway {
            plan: owned_plan(),
        };
        let read_gateway = StubReadGateway {
            snapshot: snapshot("X", false),
            called: Arc::new(Mutex::new(false)),
        };
        let events_gateway = StubEventsGateway;
        let mut interactor = PlanAllocationAdjustInteractor::new(
            &mut output,
            &logger,
            &FakeTranslator,
            &FakeClock,
            &plan_gateway,
            &read_gateway,
            &StubAdjustGateway,
            &events_gateway,
            &PlanAllocationAdjustDebugDumpNullGateway,
            "abcd1234",
        );

        interactor
            .call(PlanAllocationAdjustInput {
                plan_id: 2,
                moves: vec![],
                auth: Some(CultivationPlanRestAuth::private(1)),
            })
            .unwrap();

        assert!(success.lock().unwrap().is_empty());
        let failure = failures.lock().unwrap();
        assert_eq!(failure.len(), 1);
        assert_eq!(
            failure[0].kind,
            PlanAllocationAdjustFailure::KIND_CROP_MISSING_GROWTH_STAGES
        );
        assert!(failure[0].message.contains("crop_name=X"));
    }
