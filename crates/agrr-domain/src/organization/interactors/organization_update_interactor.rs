//! Ruby: `Domain::Organization::Interactors::OrganizationUpdateInteractor`

use crate::organization::dtos::OrganizationUpdateInput;
use crate::organization::gateways::{OrganizationGateway, OrganizationMembershipGateway};
use crate::organization::policies::update_organization_allowed;
use crate::organization::ports::{OrganizationUpdateOutputPort, UpdateFailure};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct OrganizationUpdateInteractor<'a, G, M, O, U> {
    output_port: &'a mut O,
    gateway: &'a G,
    membership_gateway: &'a M,
    user_lookup: &'a U,
    user_id: i64,
    organization_id: i64,
}

impl<'a, G, M, O, U> OrganizationUpdateInteractor<'a, G, M, O, U>
where
    G: OrganizationGateway,
    M: OrganizationMembershipGateway,
    O: OrganizationUpdateOutputPort,
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

    pub fn call(
        &mut self,
        input: OrganizationUpdateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let membership = self
            .membership_gateway
            .find_membership(self.organization_id, self.user_id)?;

        let Some(membership) = membership else {
            if user.admin {
                return self.perform_update(input);
            }
            self.output_port
                .on_failure(UpdateFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        };

        if !user.admin && !update_organization_allowed(membership.role) {
            self.output_port
                .on_failure(UpdateFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }

        self.perform_update(input)
    }

    fn perform_update(
        &mut self,
        input: OrganizationUpdateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.gateway.update(
            self.organization_id,
            input.name.as_deref(),
            input.slug.as_deref(),
        ) {
            Ok(organization) => {
                self.output_port.on_success(organization);
                Ok(())
            }
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(UpdateFailure::NotFound);
                Ok(())
            }
            Err(err) => {
                self.output_port
                    .on_failure(UpdateFailure::Error(Error::new(err.to_string())));
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod interactors_organization_update_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/organization/interactors_organization_update_interactor_test.rs"
    ));
}
