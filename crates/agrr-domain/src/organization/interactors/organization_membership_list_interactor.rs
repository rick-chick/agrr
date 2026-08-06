//! Ruby: `Domain::Organization::Interactors::OrganizationMembershipListInteractor`

use crate::organization::dtos::OrganizationMembershipListFailure;
use crate::organization::gateways::{OrganizationGateway, OrganizationMembershipGateway};
use crate::organization::policies::member_access_allowed;
use crate::organization::ports::OrganizationMembershipListOutputPort;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct OrganizationMembershipListInteractor<'a, G, M, O, U> {
    output_port: &'a mut O,
    org_gateway: &'a G,
    membership_gateway: &'a M,
    user_lookup: &'a U,
    user_id: i64,
    organization_id: i64,
}

impl<'a, G, M, O, U> OrganizationMembershipListInteractor<'a, G, M, O, U>
where
    G: OrganizationGateway,
    M: OrganizationMembershipGateway,
    O: OrganizationMembershipListOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        org_gateway: &'a G,
        membership_gateway: &'a M,
        user_lookup: &'a U,
        user_id: i64,
        organization_id: i64,
    ) -> Self {
        Self {
            output_port,
            org_gateway,
            membership_gateway,
            user_lookup,
            user_id,
            organization_id,
        }
    }

    pub fn call(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let membership = self
            .membership_gateway
            .find_membership(self.organization_id, self.user_id)?;

        if !member_access_allowed(&user, membership.as_ref(), self.organization_id) {
            self.output_port
                .on_failure(OrganizationMembershipListFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }

        match self.org_gateway.find_by_id(self.organization_id) {
            Ok(_) => {}
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port
                    .on_failure(OrganizationMembershipListFailure::NotFound);
                return Ok(());
            }
            Err(err) => {
                self.output_port
                    .on_failure(OrganizationMembershipListFailure::Error(Error::new(
                        err.to_string(),
                    )));
                return Ok(());
            }
        }

        match self.membership_gateway.list_for_organization(self.organization_id) {
            Ok(memberships) => {
                self.output_port.on_success(memberships);
                Ok(())
            }
            Err(err) => {
                self.output_port
                    .on_failure(OrganizationMembershipListFailure::Error(Error::new(
                        err.to_string(),
                    )));
                Ok(())
            }
        }
    }
}
