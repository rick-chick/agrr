//! Ruby: `Domain::Organization::Interactors::OrganizationDeleteInteractor`

use crate::organization::gateways::{OrganizationGateway, OrganizationMembershipGateway};
use crate::organization::policies::delete_organization_allowed;
use crate::organization::ports::OrganizationDeleteOutputPort;
use crate::organization::dtos::OrganizationDeleteFailure;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct OrganizationDeleteInteractor<'a, G, M, O, U> {
    output_port: &'a mut O,
    gateway: &'a G,
    membership_gateway: &'a M,
    user_lookup: &'a U,
    user_id: i64,
    organization_id: i64,
}

impl<'a, G, M, O, U> OrganizationDeleteInteractor<'a, G, M, O, U>
where
    G: OrganizationGateway,
    M: OrganizationMembershipGateway,
    O: OrganizationDeleteOutputPort,
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
        let organization = match self.gateway.find_by_id(self.organization_id) {
            Ok(org) => org,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port
                    .on_failure(OrganizationDeleteFailure::NotFound);
                return Ok(());
            }
            Err(err) => {
                self.output_port.on_failure(OrganizationDeleteFailure::Error(
                    Error::new(err.to_string()),
                ));
                return Ok(());
            }
        };

        if organization.is_personal {
            self.output_port
                .on_failure(OrganizationDeleteFailure::PersonalOrgForbidden);
            return Ok(());
        }

        let membership = self
            .membership_gateway
            .find_membership(self.organization_id, self.user_id)?;

        let Some(membership) = membership else {
            if user.admin {
                return self.perform_delete();
            }
            self.output_port
                .on_failure(OrganizationDeleteFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        };

        if !user.admin && !delete_organization_allowed(membership.role, organization.is_personal) {
            self.output_port
                .on_failure(OrganizationDeleteFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }

        self.perform_delete()
    }

    fn perform_delete(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.gateway.delete(self.organization_id) {
            Ok(()) => {
                self.output_port.on_success();
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port
                    .on_failure(OrganizationDeleteFailure::NotFound);
                Ok(())
            }
            Err(err) => {
                self.output_port.on_failure(OrganizationDeleteFailure::Error(
                    Error::new(err.to_string()),
                ));
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod interactors_organization_delete_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/organization/interactors_organization_delete_interactor_test.rs"
    ));
}
