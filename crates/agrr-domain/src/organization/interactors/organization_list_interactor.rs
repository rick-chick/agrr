//! Ruby: `Domain::Organization::Interactors::OrganizationListInteractor`

use crate::organization::dtos::OrganizationListFailure;
use crate::organization::gateways::OrganizationGateway;
use crate::organization::ports::OrganizationListOutputPort;
use crate::shared::dtos::Error;
use crate::shared::gateways::UserLookupGateway;

pub struct OrganizationListInteractor<'a, G, O, U> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_lookup: &'a U,
    user_id: i64,
}

impl<'a, G, O, U> OrganizationListInteractor<'a, G, O, U>
where
    G: OrganizationGateway,
    O: OrganizationListOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        gateway: &'a G,
        user_lookup: &'a U,
        user_id: i64,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_lookup,
            user_id,
        }
    }

    pub fn call(&mut self) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let _user = self.user_lookup.find(self.user_id);
        match self.gateway.list_for_user(self.user_id) {
            Ok(organizations) => {
                self.output_port.on_success(organizations);
                Ok(())
            }
            Err(err) => {
                self.output_port
                    .on_failure(OrganizationListFailure::Error(Error::new(
                        err.to_string(),
                    )));
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod interactors_organization_list_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/organization/interactors_organization_list_interactor_test.rs"
    ));
}
