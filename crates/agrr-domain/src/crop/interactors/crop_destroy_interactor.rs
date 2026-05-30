//! Ruby: `Domain::Crop::Interactors::CropDestroyInteractor`

use crate::crop::dtos::CropDestroyOutput;
use crate::crop::gateways::{CropGateway, SoftDeleteWithUndoOutcome};
use crate::crop::policies::{CropDestroyBlockedReason, CropDestroyPolicy};
use crate::crop::ports::{CropDestroyOutputPort, DestroyFailure};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct CropDestroyInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> CropDestroyInteractor<'a, G, O, U, T>
where
    G: CropGateway,
    O: CropDestroyOutputPort,
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
        crop_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = crop_policy::record_access_filter(user);
        let opts = TranslateOptions::default();

        let current = match self.gateway.find_by_id(crop_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("crops.flash.not_found", &opts);
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

        let usage = self.gateway.find_delete_usage(crop_id)?;
        if let Some(reason) = CropDestroyPolicy::blocked_reason(&usage) {
            let key = match reason {
                CropDestroyBlockedReason::CultivationPlan => {
                    "crops.flash.cannot_delete_in_use.plan"
                }
                CropDestroyBlockedReason::Other => "crops.flash.cannot_delete_in_use.other",
            };
            let message = self.translator.t(key, &opts);
            self.output_port
                .on_failure(DestroyFailure::Error(Error::new(message)));
            return Ok(());
        }

        match self.gateway.soft_delete_with_undo(&user, crop_id, 5000, "") {
            Ok(SoftDeleteWithUndoOutcome::Success { undo }) => {
                self.output_port
                    .on_success(CropDestroyOutput::new(undo));
                Ok(())
            }
            Ok(SoftDeleteWithUndoOutcome::Failure(error)) => {
                self.output_port.on_failure(DestroyFailure::Error(error));
                Ok(())
            }
            Err(err) => {
                if err.downcast_ref::<RecordInvalidError>().is_some() {
                    self.output_port
                        .on_failure(DestroyFailure::Error(Error::new(err.to_string())));
                    return Ok(());
                }
                Err(err)
            }
        }
    }
}

#[cfg(test)]
mod interactors_crop_destroy_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_destroy_interactor_test.rs"));
}
