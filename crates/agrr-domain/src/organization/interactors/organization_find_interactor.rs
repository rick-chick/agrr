//! Ruby: `Domain::Organization::Interactors::OrganizationFindInteractor`

use crate::organization::dtos::OrganizationFindFailure;
use crate::organization::gateways::{OrganizationGateway, OrganizationMembershipGateway};
use crate::organization::policies::member_access_allowed;
use crate::organization::ports::OrganizationFindOutputPort;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct OrganizationFindInteractor<'a, G, M, O, U> {
    output_port: &'a mut O,
    gateway: &'a G,
    membership_gateway: &'a M,
    user_lookup: &'a U,
    user_id: i64,
    organization_id: i64,
}

impl<'a, G, M, O, U> OrganizationFindInteractor<'a, G, M, O, U>
where
    G: OrganizationGateway,
    M: OrganizationMembershipGateway,
    O: OrganizationFindOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        gateway: &'a G,
        membership_gateway: &'a M,
        user_lookup: &'a U,
        user_id: i64,
        organization_id: i64,
    ) -> Self {
        Self {
            output_port,
            gateway,
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
                .on_failure(OrganizationFindFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }

        match self.gateway.find_by_id(self.organization_id) {
            Ok(organization) => {
                self.output_port.on_success(organization);
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port
                    .on_failure(OrganizationFindFailure::NotFound);
                Ok(())
            }
            Err(err) => {
                self.output_port
                    .on_failure(OrganizationFindFailure::Error(Error::new(
                        err.to_string(),
                    )));
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod interactors_organization_find_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/organization/interactors_organization_find_interactor_test.rs"
    ));
}
