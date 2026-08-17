//! Ruby: `Domain::CultivationPlan::Interactors::PlanVarianceLearningReoptimizeInteractor`

use crate::cultivation_plan::gateways::CultivationPlanGateway;
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::ports::{
    PlanVarianceLearningReoptimizeOutputPort, PrivatePlanOptimizationJobChainGateway,
};
use crate::shared::gateways::UserOrganizationScopeGateway;
use crate::shared::org_scope::member_organization_ids;

pub struct PlanVarianceLearningReoptimizeInteractor<'a, O, P, J, S> {
    output_port: &'a mut O,
    plan_gateway: &'a P,
    optimization_job_chain_gateway: &'a J,
    scope_gateway: &'a S,
}

impl<'a, O, P, J, S> PlanVarianceLearningReoptimizeInteractor<'a, O, P, J, S>
where
    O: PlanVarianceLearningReoptimizeOutputPort,
    P: CultivationPlanGateway,
    J: PrivatePlanOptimizationJobChainGateway,
    S: UserOrganizationScopeGateway,
{
    pub fn new(
        output_port: &'a mut O,
        plan_gateway: &'a P,
        optimization_job_chain_gateway: &'a J,
        scope_gateway: &'a S,
    ) -> Self {
        Self {
            output_port,
            plan_gateway,
            optimization_job_chain_gateway,
            scope_gateway,
        }
    }

    pub fn call(
        &mut self,
        user_id: i64,
        plan_id: i64,
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

        match self
            .optimization_job_chain_gateway
            .enqueue_after_create(plan_id)
        {
            Ok(()) => {
                self.output_port.on_success(plan_id);
            }
            Err(_) => {
                self.output_port.on_enqueue_failed();
            }
        }

        Ok(())
    }
}

#[cfg(test)]
mod interactors_plan_variance_learning_reoptimize_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/cultivation_plan/interactors_plan_variance_learning_reoptimize_interactor_test.rs"
    ));
}
