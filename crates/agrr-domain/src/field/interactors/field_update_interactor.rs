//! Ruby: `Domain::Field::Interactors::FieldUpdateInteractor`

use crate::field::dtos::FieldUpdateInput;
use crate::field::gateways::FieldGateway;
use crate::field::policies::{assert_field_edit_on_farm_allowed, assert_owned};
use crate::field::ports::{FieldUpdateOutputPort, UpdateFailure};
use crate::shared::dtos::error::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::Field::Interactors::FieldUpdateInteractor`
pub struct FieldUpdateInteractor<'a, G, O, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a L,
}

impl<'a, G, O, L> FieldUpdateInteractor<'a, G, O, L>
where
    G: FieldGateway,
    O: FieldUpdateOutputPort,
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

    pub fn call(
        &mut self,
        update_input: FieldUpdateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        match self.gateway.field_with_farm(update_input.id) {
            Ok(with_farm) => {
                if let Err(policy) = assert_owned(&user, &with_farm.farm) {
                    self.output_port.on_failure(UpdateFailure::Policy(policy));
                    return Ok(());
                }
                if let Err(policy) = assert_field_edit_on_farm_allowed(&user, &with_farm.farm)
                {
                    self.output_port.on_failure(UpdateFailure::Policy(policy));
                    return Ok(());
                }
                match self.gateway.update(update_input.id, &update_input) {
                    Ok(field) => {
                        self.output_port.on_success(field);
                        Ok(())
                    }
                    Err(err) => Self::handle_gateway_error(&mut self.output_port, err),
                }
            }
            Err(err) => Self::handle_gateway_error(&mut self.output_port, err),
        }
    }

    fn handle_gateway_error(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(policy) = err.downcast_ref::<PolicyPermissionDenied>() {
            output_port.on_failure(UpdateFailure::Policy(*policy));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some()
            || err.downcast_ref::<RecordInvalidError>().is_some()
        {
            output_port.on_failure(UpdateFailure::Error(Error::new(err.to_string())));
            return Ok(());
        }
        Err(err)
    }
}

#[cfg(test)]
mod interactors_field_update_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field/interactors_field_update_interactor_test.rs"));
}
