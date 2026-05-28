//! Ruby: `Domain::Field::Interactors::FieldCreateInteractor`

use crate::field::dtos::FieldCreateInput;
use crate::field::gateways::FieldGateway;
use crate::field::policies::{
    assert_farm_fields_list_allowed, assert_field_edit_on_farm_allowed,
};
use crate::field::ports::{CreateFailure, FieldCreateOutputPort};
use crate::shared::dtos::error::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::{farm_policy, policy_permission_denied::PolicyPermissionDenied};

/// Ruby: `Domain::Field::Interactors::FieldCreateInteractor`
pub struct FieldCreateInteractor<'a, G, O, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a L,
}

impl<'a, G, O, L> FieldCreateInteractor<'a, G, O, L>
where
    G: FieldGateway,
    O: FieldCreateOutputPort,
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
        create_input: FieldCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let farm_access_filter = farm_policy::record_access_filter(user);
        match self.gateway.farm_fields_list(create_input.farm_id) {
            Ok(list) => {
                if let Err(policy) = assert_field_edit_on_farm_allowed(&user, &list.farm) {
                    self.output_port.on_failure(CreateFailure::Policy(policy));
                    return Ok(());
                }
                if let Err(policy) = assert_farm_fields_list_allowed(&user, &list.farm)
                {
                    self.output_port.on_failure(CreateFailure::Policy(policy));
                    return Ok(());
                }
                match self.gateway.create(
                    &create_input,
                    create_input.farm_id,
                    &farm_access_filter,
                ) {
                    Ok(field) => {
                        self.output_port.on_success(field);
                        Ok(())
                    }
                    Err(err) => Self::handle_err(&mut self.output_port, err),
                }
            }
            Err(err) => Self::handle_err(&mut self.output_port, err),
        }
    }

    fn handle_err(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(policy) = err.downcast_ref::<PolicyPermissionDenied>() {
            output_port.on_failure(CreateFailure::Policy(*policy));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some()
            || err.downcast_ref::<RecordInvalidError>().is_some()
        {
            output_port.on_failure(CreateFailure::Error(Error::new(err.to_string())));
            return Ok(());
        }
        Err(err)
    }
}
