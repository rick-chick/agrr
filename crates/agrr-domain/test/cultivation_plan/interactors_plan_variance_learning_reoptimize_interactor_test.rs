// Tests for `interactors/plan_variance_learning_reoptimize_interactor.rs`.

use crate::cultivation_plan::dtos::CultivationPlanCreateAttrs;
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::cultivation_plan::interactors::PlanVarianceLearningReoptimizeInteractor;
use crate::cultivation_plan::ports::{
    PlanVarianceLearningReoptimizeOutputPort, PrivatePlanOptimizationJobChainGateway,
};
use crate::shared::user::User;
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
    plan_id: Arc<Mutex<Option<i64>>>,
}

impl PlanVarianceLearningReoptimizeOutputPort for SpyOutput {
    fn on_success(&mut self, plan_id: i64) {
        self.events.lock().unwrap().push("success".into());
        *self.plan_id.lock().unwrap() = Some(plan_id);
    }

    fn on_enqueue_failed(&mut self) {
        self.events.lock().unwrap().push("enqueue_failed".into());
    }

    fn on_not_found(&mut self) {
        self.events.lock().unwrap().push("not_found".into());
    }
}

fn private_plan(id: i64, user_id: i64) -> CultivationPlanEntity {
    CultivationPlanEntity {
        id,
        farm_id: 1,
        user_id,
        organization_id: None,
        total_area: 50.0,
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
        _: &User,
        _: i64,
    ) -> Result<String, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn delete(
        &self,
        _: i64,
        _: &User,
        _: &str,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
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

#[test]
fn enqueues_optimization_chain_for_accessible_private_plan() {
    let events = Arc::new(Mutex::new(vec![]));
    let plan_id_out = Arc::new(Mutex::new(None));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
        plan_id: Arc::clone(&plan_id_out),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(7, 42),
    };
    let enqueued = Arc::new(Mutex::new(vec![]));
    let job_chain = SpyJobChain {
        enqueued: Arc::clone(&enqueued),
        fail: false,
    };
    let scope_gateway = EmptyScopeGateway;

    let mut interactor = PlanVarianceLearningReoptimizeInteractor::new(
        &mut output,
        &plan_gateway,
        &job_chain,
        &scope_gateway,
    );

    interactor.call(42, 7).expect("call");

    assert_eq!(*events.lock().unwrap(), vec!["success"]);
    assert_eq!(*plan_id_out.lock().unwrap(), Some(7));
    assert_eq!(*enqueued.lock().unwrap(), vec![7]);
}

#[test]
fn returns_not_found_when_user_cannot_access_plan() {
    let events = Arc::new(Mutex::new(vec![]));
    let plan_id_out = Arc::new(Mutex::new(None));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
        plan_id: Arc::clone(&plan_id_out),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(7, 99),
    };
    let enqueued = Arc::new(Mutex::new(vec![]));
    let job_chain = SpyJobChain {
        enqueued: Arc::clone(&enqueued),
        fail: false,
    };
    let scope_gateway = EmptyScopeGateway;

    let mut interactor = PlanVarianceLearningReoptimizeInteractor::new(
        &mut output,
        &plan_gateway,
        &job_chain,
        &scope_gateway,
    );

    interactor.call(42, 7).expect("call");

    assert_eq!(*events.lock().unwrap(), vec!["not_found"]);
    assert!(enqueued.lock().unwrap().is_empty());
}

#[test]
fn reports_enqueue_failed_when_job_chain_rejects() {
    let events = Arc::new(Mutex::new(vec![]));
    let plan_id_out = Arc::new(Mutex::new(None));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
        plan_id: Arc::clone(&plan_id_out),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(7, 42),
    };
    let job_chain = SpyJobChain {
        enqueued: Arc::new(Mutex::new(vec![])),
        fail: true,
    };
    let scope_gateway = EmptyScopeGateway;

    let mut interactor = PlanVarianceLearningReoptimizeInteractor::new(
        &mut output,
        &plan_gateway,
        &job_chain,
        &scope_gateway,
    );

    interactor.call(42, 7).expect("call");

    assert_eq!(*events.lock().unwrap(), vec!["enqueue_failed"]);
}
