//! Ruby: `Domain::Fertilize::Interactors::FertilizeDetailInteractor`

use crate::fertilize::dtos::FertilizeDetailOutput;
use crate::fertilize::gateways::FertilizeGateway;
use crate::fertilize::ports::{DetailFailure, FertilizeDetailOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::fertilize_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct FertilizeDetailInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> FertilizeDetailInteractor<'a, G, O, U, T>
where
    G: FertilizeGateway,
    O: FertilizeDetailOutputPort,
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

        let entity = match self.gateway.find_by_id(fertilize_id) {
            Ok(e) => e,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("fertilizes.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DetailFailure::Error(Error::new(message)));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_view_allowed(&access_filter, &entity)
        {
            self.output_port.on_failure(DetailFailure::Policy(policy));
            return Ok(());
        }

        self.output_port
            .on_success(FertilizeDetailOutput::new(&entity));
        Ok(())
    }
}

#[cfg(test)]
mod interactors_fertilize_detail_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/fertilize/interactors_fertilize_detail_interactor_test.rs"));
}
