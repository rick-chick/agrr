//! Ruby: `Domain::Farm::Interactors::FarmListInteractor`

use crate::farm::dtos::FarmListInput;
use crate::farm::gateways::FarmGateway;
use crate::farm::ports::{FarmListOutputPort, FarmListSuccess, ListFailure};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::gateways::UserOrganizationScopeGateway;
use crate::shared::org_scope::member_organization_ids;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct FarmListInteractor<'a, G, O, S> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    scope_gateway: &'a S,
}

impl<'a, G, O, S> FarmListInteractor<'a, G, O, S>
where
    G: FarmGateway,
    O: FarmListOutputPort,
    S: UserOrganizationScopeGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        scope_gateway: &'a S,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            scope_gateway,
        }
    }

    pub fn call(
        &mut self,
        input: Option<FarmListInput>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let input = input.unwrap_or_default();
        let org_ids = member_organization_ids(self.scope_gateway, self.user_id)?;
        let result = if input.is_admin {
            match (
                self.gateway
                    .list_organization_scoped_and_reference_farms(&org_ids),
                self.gateway.list_reference_farms(),
            ) {
                (Ok(farms), Ok(reference_farms)) => FarmListSuccess {
                    farms,
                    reference_farms,
                },
                (Err(err), _) | (_, Err(err)) => {
                    return Self::handle_err(&mut self.output_port, err);
                }
            }
        } else {
            match self.gateway.list_organization_scoped_farms(&org_ids) {
                Ok(farms) => FarmListSuccess {
                    farms,
                    reference_farms: vec![],
                },
                Err(err) => return Self::handle_err(&mut self.output_port, err),
            }
        };

        self.output_port.on_success(result);
        Ok(())
    }

    fn handle_err(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
            output_port.on_failure(ListFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }
        if err.downcast_ref::<crate::shared::exceptions::RecordNotFoundError>().is_some() {
            output_port.on_failure(ListFailure::Error(Error::new(
                "Record not found".to_string(),
            )));
            return Ok(());
        }
        match err.downcast::<RecordInvalidError>() {
            Ok(record_invalid) => {
                output_port.on_failure(ListFailure::Error(Error::new(
                    record_invalid.to_string(),
                )));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

#[cfg(test)]
mod interactors_farm_list_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/interactors_farm_list_interactor_test.rs"));
}
