// Tests for `interactors/plan_variance_learning_proposal_progress_update_interactor.rs`.

use crate::cultivation_plan::dtos::{
    CultivationPlanCreateAttrs, PlanVarianceLearningSnapshotRead,
};
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::{CultivationPlanGateway, PlanVarianceLearningGateway};
use crate::cultivation_plan::interactors::PlanVarianceLearningProposalProgressUpdateInteractor;
use crate::cultivation_plan::ports::PlanVarianceLearningProposalProgressUpdateOutputPort;
use crate::shared::user::User;
use serde_json::Value;
use std::collections::BTreeMap;
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
    snapshot: Arc<Mutex<Option<PlanVarianceLearningSnapshotRead>>>,
}

impl PlanVarianceLearningProposalProgressUpdateOutputPort for SpyOutput {
    fn on_success(&mut self, dto: PlanVarianceLearningSnapshotRead) {
        self.events.lock().unwrap().push("success".into());
        *self.snapshot.lock().unwrap() = Some(dto);
    }

    fn on_record_invalid(
        &mut self,
        _: BTreeMap<String, Vec<String>>,
        _: &str,
    ) {
        self.events.lock().unwrap().push("record_invalid".into());
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
        _: std::collections::HashMap<String, String>,
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

struct SpyVarianceLearningGateway {
    progress_updates: Arc<Mutex<Vec<(i64, BTreeMap<String, String>)>>>,
    stored_progress: BTreeMap<String, String>,
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
    ) -> Result<Option<PlanVarianceLearningSnapshotRead>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(Some(PlanVarianceLearningSnapshotRead {
            plan_id,
            source_plan_id: None,
            summary: None,
            proposal_application_progress: self.stored_progress.clone(),
            reorganize_orchestration_progress: Default::default(),
            learn_handoff: Default::default(),
        }))
    }

    fn find_proposal_application_progress_by_plan_id(
        &self,
        _: i64,
    ) -> Result<BTreeMap<String, String>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.stored_progress.clone())
    }

    fn upsert_proposal_application_progress(
        &self,
        plan_id: i64,
        updates: &BTreeMap<String, String>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        self.progress_updates
            .lock()
            .unwrap()
            .push((plan_id, updates.clone()));
        Ok(())
    }

    fn find_reorganize_orchestration_progress_by_plan_id(
        &self,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::ReorganizeOrchestrationProgressRead,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Ok(Default::default())
    }

    fn upsert_reorganize_orchestration_progress(
        &self,
        _: i64,
        _: &crate::cultivation_plan::dtos::ReorganizeOrchestrationProgressPatch,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
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

#[test]
fn on_not_found_when_user_cannot_access_plan() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let snapshot = Arc::new(Mutex::new(None));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
        snapshot: Arc::clone(&snapshot),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(7, 99),
    };
    let progress_updates = Arc::new(Mutex::new(Vec::new()));
    let variance_gateway = SpyVarianceLearningGateway {
        progress_updates: Arc::clone(&progress_updates),
        stored_progress: BTreeMap::new(),
    };
    let scope = EmptyScopeGateway;

    let mut interactor = PlanVarianceLearningProposalProgressUpdateInteractor::new(
        &mut output,
        &plan_gateway,
        &variance_gateway,
        &scope,
    );

    let mut updates = BTreeMap::new();
    updates.insert("stage_gdd:1:2".into(), "confirmed".into());

    interactor
        .call(1, 7, updates)
        .expect("interactor returns Ok after on_not_found");

    assert_eq!(vec!["not_found"], *events.lock().unwrap());
    assert!(progress_updates.lock().unwrap().is_empty());
}

#[test]
fn on_record_invalid_for_empty_updates() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let snapshot = Arc::new(Mutex::new(None));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
        snapshot: Arc::clone(&snapshot),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(7, 1),
    };
    let progress_updates = Arc::new(Mutex::new(Vec::new()));
    let variance_gateway = SpyVarianceLearningGateway {
        progress_updates: Arc::clone(&progress_updates),
        stored_progress: BTreeMap::new(),
    };
    let scope = EmptyScopeGateway;

    let mut interactor = PlanVarianceLearningProposalProgressUpdateInteractor::new(
        &mut output,
        &plan_gateway,
        &variance_gateway,
        &scope,
    );

    interactor
        .call(1, 7, BTreeMap::new())
        .expect("interactor returns Ok after empty updates");

    assert_eq!(vec!["record_invalid"], *events.lock().unwrap());
    assert!(progress_updates.lock().unwrap().is_empty());
}

#[test]
fn on_record_invalid_for_invalid_status() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let snapshot = Arc::new(Mutex::new(None));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
        snapshot: Arc::clone(&snapshot),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(7, 1),
    };
    let progress_updates = Arc::new(Mutex::new(Vec::new()));
    let variance_gateway = SpyVarianceLearningGateway {
        progress_updates: Arc::clone(&progress_updates),
        stored_progress: BTreeMap::new(),
    };
    let scope = EmptyScopeGateway;

    let mut interactor = PlanVarianceLearningProposalProgressUpdateInteractor::new(
        &mut output,
        &plan_gateway,
        &variance_gateway,
        &scope,
    );

    let mut updates = BTreeMap::new();
    updates.insert("stage_gdd:1:2".into(), "bogus".into());

    interactor
        .call(1, 7, updates)
        .expect("interactor returns Ok after invalid status");

    assert_eq!(vec!["record_invalid"], *events.lock().unwrap());
    assert!(progress_updates.lock().unwrap().is_empty());
}

#[test]
fn on_success_upserts_proposal_progress() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let snapshot = Arc::new(Mutex::new(None));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
        snapshot: Arc::clone(&snapshot),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(7, 1),
    };
    let progress_updates = Arc::new(Mutex::new(Vec::new()));
    let mut stored = BTreeMap::new();
    stored.insert("stage_gdd:1:2".into(), "confirmed".into());
    let variance_gateway = SpyVarianceLearningGateway {
        progress_updates: Arc::clone(&progress_updates),
        stored_progress: stored,
    };
    let scope = EmptyScopeGateway;

    let mut interactor = PlanVarianceLearningProposalProgressUpdateInteractor::new(
        &mut output,
        &plan_gateway,
        &variance_gateway,
        &scope,
    );

    let mut updates = BTreeMap::new();
    updates.insert("stage_gdd:1:2".into(), "confirmed".into());

    interactor
        .call(1, 7, updates.clone())
        .expect("proposal progress update succeeds");

    assert_eq!(vec!["success"], *events.lock().unwrap());
    let saved = progress_updates.lock().unwrap();
    assert_eq!(1, saved.len());
    assert_eq!(7, saved[0].0);
    assert_eq!(updates, saved[0].1);

    let dto = snapshot.lock().unwrap().clone().expect("snapshot returned");
    assert_eq!(
        "confirmed",
        dto.proposal_application_progress
            .get("stage_gdd:1:2")
            .map(String::as_str)
            .unwrap_or_default()
    );
}
