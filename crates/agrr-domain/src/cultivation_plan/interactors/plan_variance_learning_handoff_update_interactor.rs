//! Ruby: `Domain::CultivationPlan::Interactors::PlanVarianceLearningHandoffUpdateInteractor`

use crate::cultivation_plan::dtos::{
    LearnHandoffStatePatch, assemble_plan_variance_learning_snapshot,
};
use crate::cultivation_plan::gateways::{CultivationPlanGateway, PlanVarianceLearningGateway};
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::policies::plan_variance_learning_handoff_policy;
use crate::cultivation_plan::ports::PlanVarianceLearningProposalProgressUpdateOutputPort;
use crate::shared::gateways::UserOrganizationScopeGateway;
use crate::shared::org_scope::member_organization_ids;
use crate::shared::validation::from_message;

pub struct PlanVarianceLearningHandoffUpdateInteractor<'a, O, P, V, S> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    variance_learning_gateway: &'a V,
    scope_gateway: &'a S,
}

impl<'a, O, P, V, S> PlanVarianceLearningHandoffUpdateInteractor<'a, O, P, V, S>
where
    O: PlanVarianceLearningProposalProgressUpdateOutputPort,
    P: CultivationPlanGateway,
    V: PlanVarianceLearningGateway,
    S: UserOrganizationScopeGateway,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a P,
        variance_learning_gateway: &'a V,
        scope_gateway: &'a S,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            variance_learning_gateway,
            scope_gateway,
        }
    }

    pub fn call(
        &mut self,
        user_id: i64,
        plan_id: i64,
        patch: LearnHandoffStatePatch,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let org_ids = member_organization_ids(self.scope_gateway, user_id)?;

        if !task_schedule_private_plan_access::access_allowed(
            self.plan_gateway,
            plan_id,
            user_id,
            &org_ids,
        ) {
            self.output_port.on_not_found();
            return Ok(());
        }

        if let Err(err) = plan_variance_learning_handoff_policy::validate_learn_handoff_patch(&patch) {
            let message = err
                .detail_message()
                .unwrap_or("invalid learn handoff")
                .to_string();
            self.output_port.on_record_invalid(from_message(message), "invalid learn handoff");
            return Ok(());
        }

        self.variance_learning_gateway
            .patch_learn_handoff(plan_id, &patch)?;

        let proposal_progress = self
            .variance_learning_gateway
            .find_proposal_application_progress_by_plan_id(plan_id)?;
        let orchestration_progress = self
            .variance_learning_gateway
            .find_reorganize_orchestration_progress_by_plan_id(plan_id)?;
        let learn_handoff = self
            .variance_learning_gateway
            .find_learn_handoff_by_plan_id(plan_id)?;
        let base = self.variance_learning_gateway.find_by_plan_id(plan_id)?;

        let snapshot = assemble_plan_variance_learning_snapshot(
            plan_id,
            base,
            proposal_progress,
            orchestration_progress,
            learn_handoff,
        );

        self.output_port.on_success(snapshot);
        Ok(())
    }
}

#[cfg(test)]
mod interactors_plan_variance_learning_handoff_update_interactor_test_inline {
    use super::*;

    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/interactors_plan_variance_learning_handoff_update_interactor_test.rs"
    ));
}
