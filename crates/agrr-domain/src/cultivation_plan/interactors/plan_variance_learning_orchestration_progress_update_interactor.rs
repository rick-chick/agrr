//! Ruby: `Domain::CultivationPlan::Interactors::PlanVarianceLearningOrchestrationProgressUpdateInteractor`

use crate::cultivation_plan::dtos::{
    PlanVarianceLearningSnapshotRead, ReorganizeOrchestrationProgressPatch,
};
use crate::cultivation_plan::gateways::{CultivationPlanGateway, PlanVarianceLearningGateway};
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::policies::plan_variance_learning_orchestration_progress_policy;
use crate::cultivation_plan::ports::PlanVarianceLearningProposalProgressUpdateOutputPort;
use crate::shared::gateways::UserOrganizationScopeGateway;
use crate::shared::org_scope::member_organization_ids;
use crate::shared::validation::from_message;

pub struct PlanVarianceLearningOrchestrationProgressUpdateInteractor<'a, O, P, V, S> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    variance_learning_gateway: &'a V,
    scope_gateway: &'a S,
}

impl<'a, O, P, V, S> PlanVarianceLearningOrchestrationProgressUpdateInteractor<'a, O, P, V, S>
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
        updates: ReorganizeOrchestrationProgressPatch,
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

        if let Err(err) =
            plan_variance_learning_orchestration_progress_policy::validate_reorganize_orchestration_progress_patch(
                &updates,
            )
        {
            let message = err
                .detail_message()
                .unwrap_or("invalid orchestration progress")
                .to_string();
            self.output_port.on_record_invalid(from_message(message), "invalid orchestration progress");
            return Ok(());
        }

        self.variance_learning_gateway
            .upsert_reorganize_orchestration_progress(plan_id, &updates)?;

        let proposal_progress = self
            .variance_learning_gateway
            .find_proposal_application_progress_by_plan_id(plan_id)?;
        let orchestration_progress = self
            .variance_learning_gateway
            .find_reorganize_orchestration_progress_by_plan_id(plan_id)?;

        let snapshot = match self.variance_learning_gateway.find_by_plan_id(plan_id)? {
            Some(existing) => PlanVarianceLearningSnapshotRead {
                plan_id: existing.plan_id,
                source_plan_id: existing.source_plan_id,
                summary: existing.summary,
                proposal_application_progress: proposal_progress,
                reorganize_orchestration_progress: orchestration_progress,
            },
            None => PlanVarianceLearningSnapshotRead {
                plan_id,
                source_plan_id: None,
                summary: None,
                proposal_application_progress: proposal_progress,
                reorganize_orchestration_progress: orchestration_progress,
            },
        };

        self.output_port.on_success(snapshot);
        Ok(())
    }
}
