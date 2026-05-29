//! Ruby: `Domain::Field::Interactors::FieldDetailInteractor`

use crate::field::dtos::{FieldDetailFailure, FieldDetailInput};
use crate::field::gateways::FieldGateway;
use crate::field::policies::{assert_field_edit_on_farm_allowed, assert_owned};
use crate::field::ports::{DetailFailure, FieldDetailOutputPort};
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::Field::Interactors::FieldDetailInteractor`
pub struct FieldDetailInteractor<'a, G, O, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a L,
}

impl<'a, G, O, L> FieldDetailInteractor<'a, G, O, L>
where
    G: FieldGateway,
    O: FieldDetailOutputPort,
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

    pub fn call(&mut self, input: FieldDetailInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        match self.gateway.field_with_farm(input.field_id) {
            Ok(result) => {
                if let Err(policy) = assert_owned(&user, &result.farm) {
                    self.output_port.on_failure(DetailFailure::FieldDetail(
                        failure_dto(policy.to_string(), &input),
                    ));
                    return Ok(());
                }
                if let Err(policy) = assert_field_edit_on_farm_allowed(&user, &result.farm)
                {
                    self.output_port.on_failure(DetailFailure::FieldDetail(failure_dto(
                        policy.to_string(),
                        &input,
                    )));
                    return Ok(());
                }
                self.output_port.on_success(result);
                Ok(())
            }
            Err(err) => {
                if let Some(policy) = err.downcast_ref::<PolicyPermissionDenied>() {
                    self.output_port.on_failure(DetailFailure::FieldDetail(failure_dto(
                        policy.to_string(),
                        &input,
                    )));
                    return Ok(());
                }
                if err.downcast_ref::<RecordNotFoundError>().is_some()
                    || err.downcast_ref::<RecordInvalidError>().is_some()
                {
                    self.output_port.on_failure(DetailFailure::FieldDetail(failure_dto(
                        err.to_string(),
                        &input,
                    )));
                    return Ok(());
                }
                Err(err)
            }
        }
    }
}

fn failure_dto(message: String, input: &FieldDetailInput) -> FieldDetailFailure {
    FieldDetailFailure::new(message, input.farm_id)
}

#[cfg(test)]
mod interactors_field_detail_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field/interactors_field_detail_interactor_test.rs"));
}
