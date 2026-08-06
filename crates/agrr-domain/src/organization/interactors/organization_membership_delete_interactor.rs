//! Ruby: `Domain::Organization::Interactors::OrganizationMembershipDeleteInteractor`

use crate::organization::dtos::{OrganizationMembershipDeleteFailure, OrganizationRole};
use crate::organization::gateways::OrganizationMembershipGateway;
use crate::organization::policies::manage_target_member_allowed;
use crate::organization::ports::OrganizationMembershipDeleteOutputPort;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

fn owner_count<M: OrganizationMembershipGateway>(
    membership_gateway: &M,
    organization_id: i64,
) -> Result<usize, Box<dyn std::error::Error + Send + Sync>> {
    let memberships = membership_gateway.list_for_organization(organization_id)?;
    Ok(memberships
        .iter()
        .filter(|m| m.role == OrganizationRole::Owner)
        .count())
}

pub struct OrganizationMembershipDeleteInteractor<'a, M, O, U> {
    output_port: &'a mut O,
    membership_gateway: &'a M,
    user_lookup: &'a U,
    actor_user_id: i64,
    organization_id: i64,
    target_user_id: i64,
}

impl<'a, M, O, U> OrganizationMembershipDeleteInteractor<'a, M, O, U>
where
    M: OrganizationMembershipGateway,
    O: OrganizationMembershipDeleteOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        membership_gateway: &'a M,
        user_lookup: &'a U,
        actor_user_id: i64,
        organization_id: i64,
        target_user_id: i64,
    ) -> Self {
        Self {
            output_port,
            membership_gateway,
            user_lookup,
            actor_user_id,
            organization_id,
            target_user_id,
        }
    }

    pub fn call(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
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
                        .on_failure(OrganizationMembershipDeleteFailure::Policy(
                            PolicyPermissionDenied,
                        ));
                    return Ok(());
                }
            }
        };

        let target_membership = self
            .membership_gateway
            .find_membership(self.organization_id, self.target_user_id)?;

        let Some(target_membership) = target_membership else {
            self.output_port
                .on_failure(OrganizationMembershipDeleteFailure::NotFound);
            return Ok(());
        };

        if !user.admin
            && !manage_target_member_allowed(actor_role, target_membership.role)
        {
            self.output_port
                .on_failure(OrganizationMembershipDeleteFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }

        if target_membership.role == OrganizationRole::Owner
            && owner_count(self.membership_gateway, self.organization_id)? <= 1
        {
            self.output_port
                .on_failure(OrganizationMembershipDeleteFailure::LastOwnerForbidden);
            return Ok(());
        }

        match self.membership_gateway.delete(target_membership.id) {
            Ok(()) => {
                self.output_port.on_success();
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port
                    .on_failure(OrganizationMembershipDeleteFailure::NotFound);
                Ok(())
            }
            Err(err) => {
                self.output_port
                    .on_failure(OrganizationMembershipDeleteFailure::Error(Error::new(
                        err.to_string(),
                    )));
                Ok(())
            }
        }
    }
}
