//! Ruby: `Domain::Organization::Interactors::OrganizationMembershipCreateInteractor`

use crate::organization::dtos::{
    OrganizationMembershipCreateFailure, OrganizationMembershipCreateInput, OrganizationRole,
};
use crate::organization::gateways::{OrganizationGateway, OrganizationMembershipGateway};
use crate::organization::policies::create_membership_allowed;
use crate::organization::ports::OrganizationMembershipCreateOutputPort;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct OrganizationMembershipCreateInteractor<'a, G, M, O, U> {
    output_port: &'a mut O,
    org_gateway: &'a G,
    membership_gateway: &'a M,
    user_lookup: &'a U,
    actor_user_id: i64,
    organization_id: i64,
}

impl<'a, G, M, O, U> OrganizationMembershipCreateInteractor<'a, G, M, O, U>
where
    G: OrganizationGateway,
    M: OrganizationMembershipGateway,
    O: OrganizationMembershipCreateOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        org_gateway: &'a G,
        membership_gateway: &'a M,
        user_lookup: &'a U,
        actor_user_id: i64,
        organization_id: i64,
    ) -> Self {
        Self {
            output_port,
            org_gateway,
            membership_gateway,
            user_lookup,
            actor_user_id,
            organization_id,
        }
    }

    pub fn call(
        &mut self,
        input: OrganizationMembershipCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.actor_user_id);
        let actor_membership = self
            .membership_gateway
            .find_membership(self.organization_id, self.actor_user_id)?;

        let actor_role = if user.admin {
            OrganizationRole::Owner
        } else {
            match actor_membership {
                Some(m) => m.role,
                None => {
                    self.output_port
                        .on_failure(OrganizationMembershipCreateFailure::Policy(
                            PolicyPermissionDenied,
                        ));
                    return Ok(());
                }
            }
        };

        if !user.admin && !create_membership_allowed(actor_role, input.role) {
            self.output_port
                .on_failure(OrganizationMembershipCreateFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }

        match self.org_gateway.find_by_id(self.organization_id) {
            Ok(_) => {}
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port
                    .on_failure(OrganizationMembershipCreateFailure::NotFound);
                return Ok(());
            }
            Err(err) => {
                self.output_port
                    .on_failure(OrganizationMembershipCreateFailure::Error(Error::new(
                        err.to_string(),
                    )));
                return Ok(());
            }
        }

        if self
            .membership_gateway
            .find_membership(self.organization_id, input.user_id)?
            .is_some()
        {
            self.output_port
                .on_failure(OrganizationMembershipCreateFailure::AlreadyMember);
            return Ok(());
        }

        match self
            .membership_gateway
            .create(self.organization_id, input.user_id, input.role)
        {
            Ok(membership) => {
                self.output_port.on_success(membership);
                Ok(())
            }
            Err(err) => {
                let message = err.to_string();
                if message.contains("FOREIGN KEY constraint failed") {
                    self.output_port
                        .on_failure(OrganizationMembershipCreateFailure::NotFound);
                    return Ok(());
                }
                self.output_port
                    .on_failure(OrganizationMembershipCreateFailure::Error(Error::new(message)));
                Ok(())
            }
        }
    }
}
