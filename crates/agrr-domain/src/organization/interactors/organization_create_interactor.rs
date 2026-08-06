//! Ruby: `Domain::Organization::Interactors::OrganizationCreateInteractor`

use crate::organization::dtos::OrganizationCreateInput;
use crate::organization::dtos::OrganizationRole;
use crate::organization::gateways::{OrganizationGateway, OrganizationMembershipGateway};
use crate::organization::ports::{CreateFailure, OrganizationCreateOutputPort};
use crate::shared::gateways::UserLookupGateway;

pub struct OrganizationCreateInteractor<'a, G, M, O, U> {
    output_port: &'a mut O,
    gateway: &'a G,
    membership_gateway: &'a M,
    user_lookup: &'a U,
    user_id: i64,
}

impl<'a, G, M, O, U> OrganizationCreateInteractor<'a, G, M, O, U>
where
    G: OrganizationGateway,
    M: OrganizationMembershipGateway,
    O: OrganizationCreateOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        gateway: &'a G,
        membership_gateway: &'a M,
        user_lookup: &'a U,
        user_id: i64,
    ) -> Self {
        Self {
            output_port,
            gateway,
            membership_gateway,
            user_lookup,
            user_id,
        }
    }

    pub fn call(
        &mut self,
        input: OrganizationCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let _user = self.user_lookup.find(self.user_id);
        let name = input.name.trim();
        let slug = input.slug.trim();
        if name.is_empty() || slug.is_empty() {
            self.output_port.on_failure(CreateFailure::Error(
                crate::shared::dtos::Error::new("name and slug are required"),
            ));
            return Ok(());
        }

        let organization = self.gateway.create(name, slug, false)?;
        self.membership_gateway.create(
            organization.id,
            self.user_id,
            OrganizationRole::Owner,
        )?;
        self.output_port.on_success(organization);
        Ok(())
    }
}

#[cfg(test)]
mod interactors_organization_create_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/organization/interactors_organization_create_interactor_test.rs"
    ));
}
