// Tests for `interactors/plan_variance_learning_orchestration_progress_update_interactor.rs`.

use crate::cultivation_plan::dtos::{
    CultivationPlanCreateAttrs, PlanVarianceLearningSnapshotRead,
    ReorganizeOrchestrationProgressPatch,
};
use crate::cultivation_plan::entities::{CultivationPlanEntity, FieldCultivationEntity};
use crate::cultivation_plan::gateways::{CultivationPlanGateway, PlanVarianceLearningGateway};
use crate::cultivation_plan::interactors::PlanVarianceLearningOrchestrationProgressUpdateInteractor;
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
}

impl PlanVarianceLearningProposalProgressUpdateOutputPort for SpyOutput {
    fn on_success(&mut self, _: PlanVarianceLearningSnapshotRead) {
        self.events.lock().unwrap().push("success".into());
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
    orchestration_patches: Arc<Mutex<Vec<(i64, ReorganizeOrchestrationProgressPatch)>>>,
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
            proposal_application_progress: BTreeMap::new(),
            reorganize_orchestration_progress: Default::default(),
            learn_handoff: Default::default(),
        }))
    }

    fn find_proposal_application_progress_by_plan_id(
        &self,
        _: i64,
    ) -> Result<BTreeMap<String, String>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(BTreeMap::new())
    }

    fn upsert_proposal_application_progress(
        &self,
        _: i64,
        _: &BTreeMap<String, String>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        unimplemented!()
    }

    fn find_reorganize_orchestration_progress_by_plan_id(
        &self,
        _: i64,
    ) -> Result<
        crate::cultivation_plan::dtos::ReorganizeOrchestrationProgressRead,
        Box<dyn std::error::Error + Send + Sync>,
    > {
        Ok(crate::cultivation_plan::dtos::ReorganizeOrchestrationProgressRead {
            placement: true,
            regenerate: false,
            sync_verify: false,
            return_to_learn: false,
            pipeline_active: false,
            current_phase: "idle".into(),
            last_error: None,
        })
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

#[test]
fn on_not_found_when_user_cannot_access_plan() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(7, 99),
    };
    let orchestration_patches = Arc::new(Mutex::new(Vec::new()));
    let variance_gateway = SpyVarianceLearningGateway {
        orchestration_patches: Arc::clone(&orchestration_patches),
    };
    let scope = EmptyScopeGateway;

    let mut interactor = PlanVarianceLearningOrchestrationProgressUpdateInteractor::new(
        &mut output,
        &plan_gateway,
        &variance_gateway,
        &scope,
    );

    interactor
        .call(
            1,
            7,
            ReorganizeOrchestrationProgressPatch {
                placement: Some(true),
                ..Default::default()
            },
        )
        .expect("interactor returns Ok after on_not_found");

    assert_eq!(vec!["not_found"], *events.lock().unwrap());
    assert!(orchestration_patches.lock().unwrap().is_empty());
}

#[test]
fn on_record_invalid_for_empty_patch() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(7, 1),
    };
    let orchestration_patches = Arc::new(Mutex::new(Vec::new()));
    let variance_gateway = SpyVarianceLearningGateway {
        orchestration_patches: Arc::clone(&orchestration_patches),
    };
    let scope = EmptyScopeGateway;

    let mut interactor = PlanVarianceLearningOrchestrationProgressUpdateInteractor::new(
        &mut output,
        &plan_gateway,
        &variance_gateway,
        &scope,
    );

    interactor
        .call(1, 7, ReorganizeOrchestrationProgressPatch::default())
        .expect("interactor returns Ok after validation failure");

    assert_eq!(vec!["record_invalid"], *events.lock().unwrap());
    assert!(orchestration_patches.lock().unwrap().is_empty());
}

#[test]
fn on_success_upserts_orchestration_progress() {
    let events = Arc::new(Mutex::new(Vec::new()));
    let mut output = SpyOutput {
        events: Arc::clone(&events),
    };
    let plan_gateway = StubPlanGateway {
        plan: private_plan(7, 1),
    };
    let orchestration_patches = Arc::new(Mutex::new(Vec::new()));
    let variance_gateway = SpyVarianceLearningGateway {
        orchestration_patches: Arc::clone(&orchestration_patches),
    };
    let scope = EmptyScopeGateway;
    let patch = ReorganizeOrchestrationProgressPatch {
        regenerate: Some(true),
        ..Default::default()
    };

    let mut interactor = PlanVarianceLearningOrchestrationProgressUpdateInteractor::new(
        &mut output,
        &plan_gateway,
        &variance_gateway,
        &scope,
    );

    interactor
        .call(1, 7, patch.clone())
        .expect("orchestration update succeeds");

    assert_eq!(vec!["success"], *events.lock().unwrap());
    let patches = orchestration_patches.lock().unwrap();
    assert_eq!(1, patches.len());
    assert_eq!(7, patches[0].0);
    assert_eq!(patch, patches[0].1);
}
