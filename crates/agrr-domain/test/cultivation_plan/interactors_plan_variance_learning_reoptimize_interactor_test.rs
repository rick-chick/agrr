// Tests for `interactors/plan_variance_learning_reoptimize_interactor.rs`

    use crate::cultivation_plan::dtos::{
        CultivationPlanCreateAttrs, PlanVarianceLearningReoptimizeInput,
    };
    use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
    use crate::cultivation_plan::gateways::CultivationPlanGateway;
    use crate::cultivation_plan::interactors::PlanVarianceLearningReoptimizeInteractor;
    use crate::cultivation_plan::ports::{
        PlanVarianceLearningReoptimizeEnqueuePort, PlanVarianceLearningReoptimizeOutputPort,
    };
    use serde_json::Value;
    use std::collections::HashMap;
    use std::sync::{Arc, Mutex};

    struct EmptyScopeGateway;
    impl crate::shared::gateways::UserOrganizationScopeGateway for EmptyScopeGateway {
        fn organization_ids_for_user(
            &self,
            _: i64,
        ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }
    }

    struct SpyOutput {
        events: Arc<Mutex<Vec<String>>>,
        plan_ids: Arc<Mutex<Vec<i64>>>,
    }

    impl PlanVarianceLearningReoptimizeOutputPort for SpyOutput {
        fn on_success(&mut self, plan_id: i64) {
            self.events.lock().unwrap().push("success".into());
            self.plan_ids.lock().unwrap().push(plan_id);
        }

        fn on_not_found(&mut self) {
            self.events.lock().unwrap().push("not_found".into());
        }
    }

    struct SpyEnqueue {
        calls: Arc<Mutex<Vec<i64>>>,
    }

    impl PlanVarianceLearningReoptimizeEnqueuePort for SpyEnqueue {
        fn enqueue(
            &self,
            plan_id: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            self.calls.lock().unwrap().push(plan_id);
            Ok(())
        }
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
            _: &CultivationPlanCreateAttrs,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update(
            &self,
            _: i64,
            _: HashMap<String, String>,
        ) -> Result<CultivationPlanEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_by_plan_id(
            &self,
            _: i64,
        ) -> Result<Vec<FieldCultivationEntity>, Box<dyn std::error::Error + Send + Sync>> {
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
        ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    fn private_plan(user_id: i64, plan_id: i64) -> CultivationPlanEntity {
        CultivationPlanEntity {
            id: plan_id,
            farm_id: 1,
            user_id,
            organization_id: None,
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

    #[test]
    fn call_enqueues_and_reports_success_for_owned_plan() {
        let events = Arc::new(Mutex::new(Vec::new()));
        let plan_ids = Arc::new(Mutex::new(Vec::new()));
        let enqueue_calls = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            events: events.clone(),
            plan_ids: plan_ids.clone(),
        };
        let plan_gateway = StubPlanGateway {
            plan: private_plan(1, 42),
        };
        let enqueue = SpyEnqueue {
            calls: enqueue_calls.clone(),
        };
        let mut interactor = PlanVarianceLearningReoptimizeInteractor::new(
            &mut output,
            &plan_gateway,
            &enqueue,
            &EmptyScopeGateway,
        );

        interactor
            .call(PlanVarianceLearningReoptimizeInput {
                user_id: 1,
                plan_id: 42,
            })
            .expect("call");

        assert_eq!(vec!["success"], *events.lock().unwrap());
        assert_eq!(vec![42], *plan_ids.lock().unwrap());
        assert_eq!(vec![42], *enqueue_calls.lock().unwrap());
    }

    #[test]
    fn call_reports_not_found_for_other_users_plan() {
        let events = Arc::new(Mutex::new(Vec::new()));
        let plan_ids = Arc::new(Mutex::new(Vec::new()));
        let enqueue_calls = Arc::new(Mutex::new(Vec::new()));
        let mut output = SpyOutput {
            events: events.clone(),
            plan_ids: plan_ids.clone(),
        };
        let plan_gateway = StubPlanGateway {
            plan: private_plan(99, 42),
        };
        let enqueue = SpyEnqueue {
            calls: enqueue_calls.clone(),
        };
        let mut interactor = PlanVarianceLearningReoptimizeInteractor::new(
            &mut output,
            &plan_gateway,
            &enqueue,
            &EmptyScopeGateway,
        );

        interactor
            .call(PlanVarianceLearningReoptimizeInput {
                user_id: 1,
                plan_id: 42,
            })
            .expect("call");

        assert_eq!(vec!["not_found"], *events.lock().unwrap());
        assert!(plan_ids.lock().unwrap().is_empty());
        assert!(enqueue_calls.lock().unwrap().is_empty());
    }
