// Tests for `interactors/plan_variance_learning_reoptimize_interactor.rs`

    use crate::cultivation_plan::dtos::{
        CultivationPlanCreateAttrs, PlanVarianceLearningReoptimizeInput,
        PlanVarianceLearningSnapshotRead, ReorganizeOrchestrationProgressPatch,
        ReorganizeOrchestrationProgressRead, PIPELINE_PHASE_OPTIMIZING,
    };
    use crate::cultivation_plan::gateways::PlanVarianceLearningGateway;
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

    struct SpyVarianceLearningGateway {
        orchestration_patches: Arc<Mutex<Vec<(i64, ReorganizeOrchestrationProgressPatch)>>>,
    }

    impl SpyVarianceLearningGateway {
        fn new() -> Self {
            Self {
                orchestration_patches: Arc::new(Mutex::new(Vec::new())),
            }
        }
    }

    impl PlanVarianceLearningGateway for SpyVarianceLearningGateway {
        fn save(
            &self,
            _: i64,
            _: i64,
            _: &crate::cultivation_plan::dtos::PlanVsActualSummaryRead,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_plan_id(
            &self,
            plan_id: i64,
        ) -> Result<Option<PlanVarianceLearningSnapshotRead>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(Some(PlanVarianceLearningSnapshotRead {
                plan_id,
                source_plan_id: None,
                summary: None,
                proposal_application_progress: std::collections::BTreeMap::new(),
                reorganize_orchestration_progress: ReorganizeOrchestrationProgressRead::default(),
                learn_handoff: Default::default(),
            }))
        }

        fn find_proposal_application_progress_by_plan_id(
            &self,
            _: i64,
        ) -> Result<std::collections::BTreeMap<String, String>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(std::collections::BTreeMap::new())
        }

        fn upsert_proposal_application_progress(
            &self,
            _: i64,
            _: &std::collections::BTreeMap<String, String>,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_reorganize_orchestration_progress_by_plan_id(
            &self,
            _: i64,
        ) -> Result<ReorganizeOrchestrationProgressRead, Box<dyn std::error::Error + Send + Sync>> {
            Ok(ReorganizeOrchestrationProgressRead::default())
        }

        fn upsert_reorganize_orchestration_progress(
            &self,
            plan_id: i64,
            patch: &ReorganizeOrchestrationProgressPatch,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            self.orchestration_patches
                .lock()
                .unwrap()
                .push((plan_id, patch.clone()));
            Ok(())
        }

        fn find_learn_handoff_by_plan_id(
            &self,
            _: i64,
        ) -> Result<
            crate::cultivation_plan::dtos::LearnHandoffStateRead,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            Ok(Default::default())
        }

        fn patch_learn_handoff(
            &self,
            _: i64,
            _: &crate::cultivation_plan::dtos::LearnHandoffStatePatch,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
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

    struct FailingEnqueue {
        calls: Arc<Mutex<Vec<i64>>>,
        message: String,
    }

    impl PlanVarianceLearningReoptimizeEnqueuePort for FailingEnqueue {
        fn enqueue(
            &self,
            plan_id: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            self.calls.lock().unwrap().push(plan_id);
            Err(self.message.clone().into())
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
        let variance_gateway = SpyVarianceLearningGateway::new();
        let orchestration_patches = Arc::clone(&variance_gateway.orchestration_patches);
        let mut interactor = PlanVarianceLearningReoptimizeInteractor::new(
            &mut output,
            &plan_gateway,
            &enqueue,
            &variance_gateway,
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
        let patches = orchestration_patches.lock().unwrap();
        assert_eq!(1, patches.len());
        assert_eq!(42, patches[0].0);
        assert_eq!(Some(true), patches[0].1.pipeline_active);
        assert_eq!(
            Some(PIPELINE_PHASE_OPTIMIZING.into()),
            patches[0].1.current_phase
        );
        assert_eq!(Some(None), patches[0].1.last_error);
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
        let variance_gateway = SpyVarianceLearningGateway::new();
        let orchestration_patches = Arc::clone(&variance_gateway.orchestration_patches);
        let mut interactor = PlanVarianceLearningReoptimizeInteractor::new(
            &mut output,
            &plan_gateway,
            &enqueue,
            &variance_gateway,
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
        assert!(orchestration_patches.lock().unwrap().is_empty());
    }

    #[test]
    fn call_returns_enqueue_error_after_persisting_orchestration_activation() {
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
        let enqueue = FailingEnqueue {
            calls: enqueue_calls.clone(),
            message: "optimization chain could not start".into(),
        };
        let variance_gateway = SpyVarianceLearningGateway::new();
        let orchestration_patches = Arc::clone(&variance_gateway.orchestration_patches);
        let mut interactor = PlanVarianceLearningReoptimizeInteractor::new(
            &mut output,
            &plan_gateway,
            &enqueue,
            &variance_gateway,
            &EmptyScopeGateway,
        );

        let err = interactor
            .call(PlanVarianceLearningReoptimizeInput {
                user_id: 1,
                plan_id: 42,
            })
            .expect_err("enqueue failure must surface to caller");

        assert!(
            err.to_string().contains("optimization chain could not start"),
            "unexpected error: {err}"
        );
        assert!(events.lock().unwrap().is_empty());
        assert!(plan_ids.lock().unwrap().is_empty());
        assert_eq!(vec![42], *enqueue_calls.lock().unwrap());
        let patches = orchestration_patches.lock().unwrap();
        assert_eq!(1, patches.len());
        assert_eq!(42, patches[0].0);
        assert_eq!(Some(true), patches[0].1.pipeline_active);
        assert_eq!(
            Some(PIPELINE_PHASE_OPTIMIZING.into()),
            patches[0].1.current_phase
        );
        assert_eq!(Some(None), patches[0].1.last_error);
    }
