//! Ruby: `Domain::Crop::Interactors::CropDetailInteractor`

use crate::crop::dtos::CropDetailOutput;
use crate::crop::gateways::CropGateway;
use crate::crop::ports::{CropDetailOutputPort, DetailFailure};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;
use crate::shared::reference_record_authorization;

pub struct CropDetailInteractor<'a, G, O, U> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a U,
}

impl<'a, G, O, U> CropDetailInteractor<'a, G, O, U>
where
    G: CropGateway,
    O: CropDetailOutputPort,
    U: UserLookupGateway,
{
    pub fn new(output_port: &'a mut O, user_id: i64, gateway: &'a G, user_lookup: &'a U) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        crop_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = crop_policy::record_access_filter(user);

        let crop_detail = match self.gateway.find_crop_show_detail(crop_id) {
            Ok(detail) => detail,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some()
                    || err.downcast_ref::<RecordInvalidError>().is_some()
                {
                    self.output_port
                        .on_failure(DetailFailure::Error(Error::new(err.to_string())));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_view_allowed(&access_filter, &crop_detail.crop)
        {
            self.output_port.on_failure(DetailFailure::Policy(policy));
            return Ok(());
        }

        self.output_port
            .on_success(CropDetailOutput::new(crop_detail.crop));
        Ok(())
    }
}

#[cfg(test)]
mod interactors_crop_detail_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_detail_interactor_test.rs"));
}
