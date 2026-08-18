//! System-side orchestration progress updates after optimization job chain steps.

use crate::cultivation_plan::gateways::PlanVarianceLearningGateway;
use crate::cultivation_plan::policies::optimization_chain_orchestration_progress_policy::{
    orchestration_patch_for_chain_step_failure, orchestration_patch_for_chain_step_success,
    OptimizationChainOrchestrationStep,
};
use crate::cultivation_plan::policies::plan_variance_learning_orchestration_progress_policy;

pub struct OptimizationChainOrchestrationProgressUpdateInteractor<'a, V> {
    variance_learning_gateway: &'a V,
}

impl<'a, V> OptimizationChainOrchestrationProgressUpdateInteractor<'a, V>
where
    V: PlanVarianceLearningGateway,
{
    pub fn new(variance_learning_gateway: &'a V) -> Self {
        Self {
            variance_learning_gateway,
        }
    }

    pub fn on_chain_step_success(
        &self,
        plan_id: i64,
        step: OptimizationChainOrchestrationStep,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let current = self
            .variance_learning_gateway
            .find_reorganize_orchestration_progress_by_plan_id(plan_id)?;
        let Some(patch) = orchestration_patch_for_chain_step_success(step, &current) else {
            return Ok(());
        };
        self.apply_patch(plan_id, &patch)
    }

    pub fn on_chain_step_failure(
        &self,
        plan_id: i64,
        error: &str,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let current = self
            .variance_learning_gateway
            .find_reorganize_orchestration_progress_by_plan_id(plan_id)?;
        let Some(patch) = orchestration_patch_for_chain_step_failure(&current, error) else {
            return Ok(());
        };
        self.apply_patch(plan_id, &patch)
    }

    fn apply_patch(
        &self,
        plan_id: i64,
        patch: &crate::cultivation_plan::dtos::ReorganizeOrchestrationProgressPatch,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        plan_variance_learning_orchestration_progress_policy::validate_reorganize_orchestration_progress_patch(
            patch,
        )?;
        self.variance_learning_gateway
            .upsert_reorganize_orchestration_progress(plan_id, patch)
    }
}

#[cfg(test)]
mod interactors_optimization_chain_orchestration_progress_update_interactor_test_inline {
    use super::*;

    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/interactors_optimization_chain_orchestration_progress_update_interactor_test.rs"
    ));
}
