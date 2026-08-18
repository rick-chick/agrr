// Tests for `interactors/optimization_chain_orchestration_progress_update_interactor.rs`.

use crate::cultivation_plan::dtos::{
    PlanVarianceLearningSnapshotRead, ReorganizeOrchestrationProgressPatch,
    ReorganizeOrchestrationProgressRead, PIPELINE_PHASE_REGENERATE,
};
use crate::cultivation_plan::gateways::PlanVarianceLearningGateway;
use crate::cultivation_plan::interactors::OptimizationChainOrchestrationProgressUpdateInteractor;
use crate::cultivation_plan::policies::optimization_chain_orchestration_progress_policy::OptimizationChainOrchestrationStep;
use std::collections::BTreeMap;
use std::sync::{Arc, Mutex};

struct SpyVarianceLearningGateway {
    orchestration: ReorganizeOrchestrationProgressRead,
    orchestration_patches: Arc<Mutex<Vec<(i64, ReorganizeOrchestrationProgressPatch)>>>,
}

impl SpyVarianceLearningGateway {
    fn new(orchestration: ReorganizeOrchestrationProgressRead) -> Self {
        Self {
            orchestration,
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
    ) -> Result<Option<PlanVarianceLearningSnapshotRead>, Box<dyn std::error::Error + Send + Sync>> {
        Ok(Some(PlanVarianceLearningSnapshotRead {
            plan_id,
            source_plan_id: None,
            summary: None,
            proposal_application_progress: BTreeMap::new(),
            reorganize_orchestration_progress: self.orchestration.clone(),
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
    ) -> Result<ReorganizeOrchestrationProgressRead, Box<dyn std::error::Error + Send + Sync>> {
        Ok(self.orchestration.clone())
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
fn applies_patch_on_optimization_step_success() {
    let gateway = SpyVarianceLearningGateway::new(ReorganizeOrchestrationProgressRead {
        pipeline_active: true,
        current_phase: "optimizing".into(),
        ..Default::default()
    });
    let patches = Arc::clone(&gateway.orchestration_patches);
    let interactor = OptimizationChainOrchestrationProgressUpdateInteractor::new(&gateway);

    interactor
        .on_chain_step_success(7, OptimizationChainOrchestrationStep::Optimization)
        .expect("update succeeds");

    let captured = patches.lock().unwrap();
    assert_eq!(1, captured.len());
    assert_eq!(7, captured[0].0);
    assert_eq!(Some(true), captured[0].1.placement);
    assert_eq!(Some(PIPELINE_PHASE_REGENERATE.into()), captured[0].1.current_phase);
}

#[test]
fn skips_upsert_when_pipeline_inactive() {
    let gateway = SpyVarianceLearningGateway::new(ReorganizeOrchestrationProgressRead::default());
    let patches = Arc::clone(&gateway.orchestration_patches);
    let interactor = OptimizationChainOrchestrationProgressUpdateInteractor::new(&gateway);

    interactor
        .on_chain_step_success(7, OptimizationChainOrchestrationStep::Optimization)
        .expect("noop succeeds");

    assert!(patches.lock().unwrap().is_empty());
}

#[test]
fn applies_failed_patch_on_chain_step_failure() {
    let gateway = SpyVarianceLearningGateway::new(ReorganizeOrchestrationProgressRead {
        pipeline_active: true,
        current_phase: "optimizing".into(),
        ..Default::default()
    });
    let patches = Arc::clone(&gateway.orchestration_patches);
    let interactor = OptimizationChainOrchestrationProgressUpdateInteractor::new(&gateway);

    interactor
        .on_chain_step_failure(7, "daemon unavailable")
        .expect("update succeeds");

    let captured = patches.lock().unwrap();
    assert_eq!(1, captured.len());
    assert_eq!(Some("failed".into()), captured[0].1.current_phase);
    assert_eq!(
        Some(Some("daemon unavailable".into())),
        captured[0].1.last_error
    );
}
