//! Ruby: `Domain::Fertilize::Interactors::FertilizeDestroyInteractor`

use crate::fertilize::dtos::FertilizeDestroyOutput;
use crate::fertilize::gateways::{FertilizeGateway, SoftDeleteWithUndoOutcome};
use crate::fertilize::ports::{DestroyFailure, FertilizeDestroyOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{AssociationInUseError, RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::fertilize_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct FertilizeDestroyInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> FertilizeDestroyInteractor<'a, G, O, U, T>
where
    G: FertilizeGateway,
    O: FertilizeDestroyOutputPort,
    U: UserLookupGateway,
    T: TranslatorPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        translator: &'a T,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            translator,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        fertilize_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = fertilize_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(fertilize_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("fertilizes.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DestroyFailure::Error(Error::new(message)));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_edit_allowed(&access_filter, &current)
        {
            self.output_port.on_failure(DestroyFailure::Policy(policy));
            return Ok(());
        }

        match self
            .gateway
            .soft_delete_with_undo(&user, fertilize_id, 5000, self.translator)
        {
            Ok(SoftDeleteWithUndoOutcome::Success { undo }) => {
                self.output_port
                    .on_success(FertilizeDestroyOutput::new(undo));
                Ok(())
            }
            Ok(SoftDeleteWithUndoOutcome::Failure(error)) => {
                self.output_port.on_failure(DestroyFailure::Error(error));
                Ok(())
            }
            Err(err) => Self::handle_gateway_error(&mut self.output_port, err, &opts),
        }
    }

    fn handle_gateway_error(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
        opts: &TranslateOptions,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
            output_port.on_failure(DestroyFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some() {
            output_port.on_failure(DestroyFailure::Error(Error::new("Record not found".to_string())));
            return Ok(());
        }
        if err.downcast_ref::<AssociationInUseError>().is_some() {
            let _ = opts;
            output_port.on_failure(DestroyFailure::Error(Error::new(
                "fertilizes.flash.cannot_delete_in_use".to_string(),
            )));
            return Ok(());
        }
        match err.downcast::<RecordInvalidError>() {
            Ok(record_invalid) => {
                output_port.on_failure(DestroyFailure::Error(Error::new(record_invalid.to_string())));
                Ok(())
            }
            Err(err) => Err(err),
        }
    }
}

#[cfg(test)]
mod interactors_fertilize_destroy_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/fertilize/interactors_fertilize_destroy_interactor_test.rs"));
}
