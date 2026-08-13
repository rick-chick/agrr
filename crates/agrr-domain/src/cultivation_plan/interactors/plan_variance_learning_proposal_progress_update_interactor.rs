//! Ruby: `Domain::CultivationPlan::Interactors::PlanVarianceLearningProposalProgressUpdateInteractor`

use std::collections::BTreeMap;

use crate::cultivation_plan::dtos::PlanVarianceLearningSnapshotRead;
use crate::cultivation_plan::gateways::{CultivationPlanGateway, PlanVarianceLearningGateway};
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::policies::plan_variance_learning_proposal_progress_policy;
use crate::cultivation_plan::ports::PlanVarianceLearningProposalProgressUpdateOutputPort;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserOrganizationScopeGateway;
use crate::shared::org_scope::member_organization_ids;
use crate::shared::validation::from_message;

pub struct PlanVarianceLearningProposalProgressUpdateInteractor<'a, O, P, V, S> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    variance_learning_gateway: &'a V,
    scope_gateway: &'a S,
}

impl<'a, O, P, V, S> PlanVarianceLearningProposalProgressUpdateInteractor<'a, O, P, V, S>
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
        updates: BTreeMap<String, String>,
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

        if updates.is_empty() {
            self.output_port.on_record_invalid(
                BTreeMap::new(),
                "proposal_application_progress is required",
            );
            return Ok(());
        }

        if let Err(err) =
            plan_variance_learning_proposal_progress_policy::validate_proposal_application_progress_updates(
                &updates,
            )
        {
            let message = err
                .detail_message()
                .unwrap_or("invalid proposal progress")
                .to_string();
            self.output_port.on_record_invalid(from_message(message), "invalid proposal progress");
            return Ok(());
        }

        self.variance_learning_gateway
            .upsert_proposal_application_progress(plan_id, &updates)?;

        let progress = self
            .variance_learning_gateway
            .find_proposal_application_progress_by_plan_id(plan_id)?;

        let snapshot = match self.variance_learning_gateway.find_by_plan_id(plan_id)? {
            Some(existing) => PlanVarianceLearningSnapshotRead {
                plan_id: existing.plan_id,
                source_plan_id: existing.source_plan_id,
                summary: existing.summary,
                proposal_application_progress: progress,
            },
            None => PlanVarianceLearningSnapshotRead {
                plan_id,
                source_plan_id: None,
                summary: None,
                proposal_application_progress: progress,
            },
        };

        self.output_port.on_success(snapshot);
        Ok(())
    }
}
