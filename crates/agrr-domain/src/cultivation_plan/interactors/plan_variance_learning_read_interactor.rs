//! Ruby: `Domain::CultivationPlan::Interactors::PlanVarianceLearningReadInteractor`

use crate::cultivation_plan::dtos::{
    PlanVarianceLearningSnapshotRead, ReorganizeOrchestrationProgressRead,
    assemble_plan_variance_learning_snapshot,
};
use crate::cultivation_plan::gateways::{CultivationPlanGateway, PlanVarianceLearningGateway};
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::ports::PlanVarianceLearningReadOutputPort;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::{UserLookupGateway, UserOrganizationScopeGateway};
use crate::shared::org_scope::member_organization_ids;
use crate::shared::ports::{LoggerPort, TranslatorPort};

pub struct PlanVarianceLearningReadInteractor<'a, O, G, V, U, L, T, S> {
    output_port: &'a mut O,
    user_id: i64,
    plan_id: i64,
    cultivation_plan_gateway: &'a G,
    variance_learning_gateway: &'a V,
    translator: &'a T,
    logger: &'a L,
    user_lookup: &'a U,
    scope_gateway: &'a S,
}

impl<'a, O, G, V, U, L, T, S> PlanVarianceLearningReadInteractor<'a, O, G, V, U, L, T, S>
where
    O: PlanVarianceLearningReadOutputPort,
    G: CultivationPlanGateway,
    V: PlanVarianceLearningGateway,
    U: UserLookupGateway,
    L: LoggerPort,
    T: TranslatorPort,
    S: UserOrganizationScopeGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        plan_id: i64,
        cultivation_plan_gateway: &'a G,
        variance_learning_gateway: &'a V,
        translator: &'a T,
        logger: &'a L,
        user_lookup: &'a U,
        scope_gateway: &'a S,
    ) -> Self {
        Self {
            output_port,
            user_id,
            plan_id,
            cultivation_plan_gateway,
            variance_learning_gateway,
            translator,
            logger,
            user_lookup,
            scope_gateway,
        }
    }

    pub fn call(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let org_ids = member_organization_ids(self.scope_gateway, user.id)?;

        if !task_schedule_private_plan_access::access_allowed(
            self.cultivation_plan_gateway,
            self.plan_id,
            user.id,
            &org_ids,
        ) {
            return Err(Box::new(RecordNotFoundError));
        }

        let progress = self
            .variance_learning_gateway
            .find_proposal_application_progress_by_plan_id(self.plan_id)?;
        let orchestration = self
            .variance_learning_gateway
            .find_reorganize_orchestration_progress_by_plan_id(self.plan_id)?;
        let learn_handoff = self
            .variance_learning_gateway
            .find_learn_handoff_by_plan_id(self.plan_id)?;

        match self.variance_learning_gateway.find_by_plan_id(self.plan_id) {
            Ok(Some(snapshot)) => {
                self.output_port.on_success(assemble_plan_variance_learning_snapshot(
                    snapshot.plan_id,
                    Some(snapshot),
                    progress,
                    orchestration,
                    learn_handoff,
                ));
                Ok(())
            }
            Ok(None) => {
                if progress.is_empty()
                    && orchestration == ReorganizeOrchestrationProgressRead::default()
                    && learn_handoff.is_empty()
                {
                    self.logger.warn("[PlanVarianceLearningReadInteractor] snapshot_not_found");
                    self.output_port
                        .on_failure(Error::new(self.translator.t("plans.errors.not_found", &Default::default())));
                } else {
                    self.output_port.on_success(assemble_plan_variance_learning_snapshot(
                        self.plan_id,
                        None,
                        progress,
                        orchestration,
                        learn_handoff,
                    ));
                }
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}
