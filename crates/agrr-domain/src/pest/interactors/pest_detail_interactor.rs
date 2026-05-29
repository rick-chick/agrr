//! Ruby: `Domain::Pest::Interactors::PestDetailInteractor`

use crate::pest::dtos::PestDetailOutput;
use crate::pest::gateways::PestGateway;
use crate::pest::ports::{DetailFailure, PestDetailOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pest_policy;
use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
use crate::shared::reference_record_authorization;

pub struct PestDetailInteractor<'a, G, O, U, T> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    translator: &'a T,
    user_lookup: &'a U,
}

impl<'a, G, O, U, T> PestDetailInteractor<'a, G, O, U, T>
where
    G: PestGateway,
    O: PestDetailOutputPort,
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

        let detail = match self.gateway.find_pest_show_detail(pest_id) {
            Ok(dto) => dto,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    let message = self.translator.t("pests.flash.not_found", &opts);
                    self.output_port
                        .on_failure(DetailFailure::Error(Error::new(message)));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(_) =
            reference_record_authorization::assert_view_allowed(&access_filter, &detail.pest)
        {
            let message = self.translator.t("pests.flash.no_permission", &opts);
            self.output_port
                .on_failure(DetailFailure::Error(Error::new(message)));
            return Ok(());
        }

        self.output_port
            .on_success(PestDetailOutput::from_show_detail(detail));
        Ok(())
    }
}

#[cfg(test)]
mod interactors_pest_detail_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/interactors_pest_detail_interactor_test.rs"));
}
