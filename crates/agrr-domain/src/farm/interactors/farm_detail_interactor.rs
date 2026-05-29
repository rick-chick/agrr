//! Ruby: `Domain::Farm::Interactors::FarmDetailInteractor`

use crate::farm::dtos::FarmDetailOutput;
use crate::farm::entities::FarmEntity;
use crate::farm::gateways::FarmGateway;
use crate::farm::ports::{DetailFailure, FarmDetailOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::farm_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::reference_record_authorization;

pub struct FarmDetailInteractor<'a, G, O, U> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a U,
}

impl<'a, G, O, U> FarmDetailInteractor<'a, G, O, U>
where
    G: FarmGateway,
    O: FarmDetailOutputPort,
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
        farm_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = farm_policy::record_access_filter(user);

        let farm_entity = self.gateway.find_by_id(farm_id)?;
        if let Err(policy) =
            reference_record_authorization::assert_view_allowed(&access_filter, &farm_entity)
        {
            self.output_port.on_failure(DetailFailure::Policy(policy));
            return Ok(());
        }

        match self.gateway.farm_detail_with_fields(farm_id) {
            Ok(dto) => {
                self.output_port.on_success(dto);
                Ok(())
            }
            Err(err) => Self::handle_gateway_error(&mut self.output_port, err),
        }
    }

    fn handle_gateway_error(
        output_port: &mut O,
        err: Box<dyn std::error::Error + Send + Sync>,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if err.downcast_ref::<PolicyPermissionDenied>().is_some() {
            output_port.on_failure(DetailFailure::Policy(PolicyPermissionDenied));
            return Ok(());
        }
        if err.downcast_ref::<RecordNotFoundError>().is_some()
            || err.downcast_ref::<RecordInvalidError>().is_some()
        {
            output_port.on_failure(DetailFailure::Error(Error::new(err.to_string())));
            return Ok(());
        }
        Err(err)
    }
}

#[cfg(test)]
mod interactors_farm_detail_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/farm/interactors_farm_detail_interactor_test.rs"));
}
