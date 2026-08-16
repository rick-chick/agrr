//! Ruby: `Domain::CultivationPlan::Interactors::WeatherRescheduleProposalsListInteractor`

use crate::cultivation_plan::gateways::{
    CultivationPlanGateway, WeatherRescheduleProposalsGateway,
};
use crate::cultivation_plan::interactors::task_schedule_private_plan_access;
use crate::cultivation_plan::ports::WeatherRescheduleProposalsListOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::{UserLookupGateway, UserOrganizationScopeGateway};
use crate::shared::org_scope::member_organization_ids;

pub struct WeatherRescheduleProposalsListInteractor<'a, O, G, W, U, S> {
    output_port: &'a mut O,
    user_id: i64,
    plan_id: i64,
    cultivation_plan_gateway: &'a G,
    proposals_gateway: &'a W,
    user_lookup: &'a U,
    scope_gateway: &'a S,
}

impl<'a, O, G, W, U, S> WeatherRescheduleProposalsListInteractor<'a, O, G, W, U, S>
where
    O: WeatherRescheduleProposalsListOutputPort,
    G: CultivationPlanGateway,
    W: WeatherRescheduleProposalsGateway,
    U: UserLookupGateway,
    S: UserOrganizationScopeGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        plan_id: i64,
        cultivation_plan_gateway: &'a G,
        proposals_gateway: &'a W,
        user_lookup: &'a U,
        scope_gateway: &'a S,
    ) -> Self {
        Self {
            output_port,
            user_id,
            plan_id,
            cultivation_plan_gateway,
            proposals_gateway,
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

        let proposals = self.proposals_gateway.list_by_plan_id(self.plan_id)?;
        self.output_port.on_success(proposals);
        Ok(())
    }
}
