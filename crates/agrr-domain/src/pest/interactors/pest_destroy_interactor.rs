//! Ruby: `Domain::Pest::Interactors::PestDestroyInteractor`

use crate::pest::dtos::PestDestroyOutput;
use crate::pest::gateways::{PestGateway, SoftDeleteWithUndoOutcome};
use crate::pest::policies::{blocked_reason, PestDestroyBlockedReason};
use crate::pest::ports::{DestroyFailure, PestDestroyOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pest_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct PestDestroyInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> PestDestroyInteractor<'a, G, O, U, T>
where
    G: PestGateway,
    O: PestDestroyOutputPort,
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
        pest_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = pest_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(pest_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("pests.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DestroyFailure::Error(Error::new(message)));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(_) =
            reference_record_authorization::assert_edit_allowed(&access_filter, &current)
        {
            let message = self.translator.t("pests.flash.no_permission", &opts);
            self.output_port
                .on_failure(DestroyFailure::Error(Error::new(message)));
            return Ok(());
        }

        let usage = self.gateway.find_delete_usage(pest_id)?;
        if blocked_reason(&usage) == Some(PestDestroyBlockedReason::PesticidesInUse) {
            let message = self
                .translator
                .t("pests.flash.cannot_delete_in_use", &opts);
            self.output_port
                .on_failure(DestroyFailure::Error(Error::new(message)));
            return Ok(());
        }

        match self
            .gateway
            .soft_delete_with_undo(&user, pest_id, 5000, self.translator)
        {
            Ok(SoftDeleteWithUndoOutcome::Success { undo }) => {
                self.output_port
                    .on_success(PestDestroyOutput::new(undo));
                Ok(())
            }
            Ok(SoftDeleteWithUndoOutcome::Failure(error)) => {
                self.output_port.on_failure(DestroyFailure::Error(error));
                Ok(())
            }
            Err(err) => {
                if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
                    self.output_port.on_failure(DestroyFailure::Policy(PolicyPermissionDenied));
                    return Ok(());
                }
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("pests.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DestroyFailure::Error(Error::new(message)));
                    return Ok(());
                }
                match err.downcast::<RecordInvalidError>() {
                    Ok(record_invalid) => {
                        self.output_port.on_failure(DestroyFailure::Error(Error::new(
                            record_invalid.to_string(),
                        )));
                        Ok(())
                    }
                    Err(err) => Err(err),
                }
            }
        }
    }
}

#[cfg(test)]
mod interactors_pest_destroy_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/interactors_pest_destroy_interactor_test.rs"));
}
