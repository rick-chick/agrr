//! Ruby: `Domain::Field::Interactors::FieldListInteractor`

use crate::field::gateways::FieldGateway;
use crate::field::policies::{
    assert_farm_fields_list_allowed, assert_field_edit_on_farm_allowed,
};
use crate::field::ports::{FieldListOutputPort, ListFailure};
use crate::shared::dtos::error::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::Field::Interactors::FieldListInteractor`
pub struct FieldListInteractor<'a, G, O, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a L,
}

impl<'a, G, O, L> FieldListInteractor<'a, G, O, L>
where
    G: FieldGateway,
    O: FieldListOutputPort,
    L: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        user_lookup: &'a L,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            user_lookup,
        }
    }

    pub fn call(&mut self, farm_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        match self.gateway.farm_fields_list(farm_id) {
            Ok(result) => {
                if let Err(policy) = assert_field_edit_on_farm_allowed(&user, &result.farm) {
                    self.output_port.on_failure(ListFailure::Policy(policy));
                    return Ok(());
                }
                if let Err(policy) = assert_farm_fields_list_allowed(&user, &result.farm)
                {
                    self.output_port.on_failure(ListFailure::Policy(policy));
                    return Ok(());
                }
                self.output_port.on_success(result);
                Ok(())
            }
            Err(err) => {
                if let Some(policy) = err.downcast_ref::<PolicyPermissionDenied>() {
                    self.output_port.on_failure(ListFailure::Policy(*policy));
                    return Ok(());
                }
                if err.downcast_ref::<RecordNotFoundError>().is_some()
                    || err.downcast_ref::<RecordInvalidError>().is_some()
                {
                    self.output_port
                        .on_failure(ListFailure::Error(Error::new(err.to_string())));
                    return Ok(());
                }
                Err(err)
            }
        }
    }
}

#[cfg(test)]
mod interactors_field_list_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field/interactors_field_list_interactor_test.rs"));
}
