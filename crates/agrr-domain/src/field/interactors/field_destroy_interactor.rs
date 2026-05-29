//! Ruby: `Domain::Field::Interactors::FieldDestroyInteractor`

use crate::field::dtos::FieldDestroyOutput;
use crate::field::gateways::FieldGateway;
use crate::field::policies::{assert_field_edit_on_farm_allowed, assert_owned};
use crate::field::ports::{DestroyFailure, FieldDestroyOutputPort};
use crate::shared::dtos::error::Error;
use crate::shared::exceptions::{AssociationInUseError, RecordNotFoundError};
use crate::shared::gateways::user_lookup_gateway::UserLookupGateway;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};

/// Ruby: `Domain::Field::Interactors::FieldDestroyInteractor`
pub struct FieldDestroyInteractor<'a, G, O, L, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a L,
}

impl<'a, G, O, L, T> FieldDestroyInteractor<'a, G, O, L, T>
where
    G: FieldGateway,
    O: FieldDestroyOutputPort,
    L: UserLookupGateway,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        translator: &'a T,
        user_lookup: &'a L,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            translator,
            user_lookup,
        }
    }

    pub fn call(&mut self, field_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let opts = TranslateOptions::default();
        match self.gateway.field_with_farm(field_id) {
            Ok(with_farm) => {
                if let Err(policy) = assert_owned(&user, &with_farm.farm) {
                    self.output_port.on_failure(DestroyFailure::Policy(policy));
                    return Ok(());
                }
                if let Err(policy) = assert_field_edit_on_farm_allowed(&user, &with_farm.farm)
                {
                    self.output_port.on_failure(DestroyFailure::Policy(policy));
                    return Ok(());
                }
                match self.gateway.delete(field_id) {
                    Ok(undo) => {
                        self.output_port
                            .on_success(FieldDestroyOutput::new(undo));
                        Ok(())
                    }
                    Err(err) => Self::handle_err(&mut self.output_port, &*self.translator, &opts, err),
                }
            }
            Err(err) => Self::handle_err(&mut self.output_port, &*self.translator, &opts, err),
        }
    }

    fn handle_err(
        output_port: &mut O,
        translator: &dyn TranslatorPort,
        opts: &TranslateOptions,
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if let Some(policy) = err.downcast_ref::<PolicyPermissionDenied>() {
            output_port.on_failure(DestroyFailure::Policy(*policy));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some() {
            output_port.on_failure(DestroyFailure::Error(Error::new(err.to_string())));
            return Ok(());
        }
        if err.downcast_ref::<AssociationInUseError>().is_some() {
            let message = translator.t("fields.flash.cannot_delete_in_use", opts);
            output_port.on_failure(DestroyFailure::Error(Error::new(message)));
            return Ok(());
        }
        Err(err)
    }
}

#[cfg(test)]
mod interactors_field_destroy_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/field/interactors_field_destroy_interactor_test.rs"));
}
