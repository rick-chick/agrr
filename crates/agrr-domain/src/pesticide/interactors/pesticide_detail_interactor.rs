//! Ruby: `Domain::Pesticide::Interactors::PesticideDetailInteractor`

use crate::pesticide::dtos::PesticideDetailOutput;
use crate::pesticide::gateways::PesticideGateway;
use crate::pesticide::ports::{DetailFailure, PesticideDetailOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pesticide_policy;
use crate::shared::reference_record_authorization;

pub struct PesticideDetailInteractor<'a, G, O, U> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a U,
}

impl<'a, G, O, U> PesticideDetailInteractor<'a, G, O, U>
where
    G: PesticideGateway,
    O: PesticideDetailOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        user_lookup: &'a U,
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
        pesticide_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = pesticide_policy::record_access_filter(user);

        let dto = match self.gateway.find_pesticide_show_detail(pesticide_id) {
            Ok(d) => d,
            Err(err) => {
                if err.downcast_ref::<RecordInvalidError>().is_some() {
                    self.output_port
                        .on_failure(DetailFailure::Error(Error::new(err.to_string())));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if let Err(policy) =
            reference_record_authorization::assert_view_allowed(&access_filter, &dto.pesticide)
        {
            self.output_port.on_failure(DetailFailure::Policy(policy));
            return Ok(());
        }

        self.output_port.on_success(PesticideDetailOutput::new(
            dto.pesticide,
            dto.crop_name,
            dto.pest_name,
            dto.usage_constraint_snapshot,
            dto.application_detail_snapshot,
        ));
        Ok(())
    }
}

#[cfg(test)]
mod interactors_pesticide_detail_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pesticide/interactors_pesticide_detail_interactor_test.rs"));
}
