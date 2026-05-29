//! Ruby: `Domain::Pesticide::Interactors::MastersCropPesticidesIndexInteractor`

use crate::pesticide::gateways::{CropGateway, PesticideGateway};
use crate::pesticide::policies::assert_edit_allowed_for_masters;
use crate::pesticide::ports::MastersCropPesticidesIndexOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::pesticide_policy;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub struct MastersCropPesticidesIndexInteractor<'a, PG, CG, O, U> {
    output_port: &'a mut O,
    user_id: i64,
    user_lookup: &'a U,
    pesticide_gateway: &'a PG,
    crop_gateway: &'a CG,
}

impl<'a, PG, CG, O, U> MastersCropPesticidesIndexInteractor<'a, PG, CG, O, U>
where
    PG: PesticideGateway,
    CG: CropGateway,
    O: MastersCropPesticidesIndexOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        user_lookup: &'a U,
        pesticide_gateway: &'a PG,
        crop_gateway: &'a CG,
    ) -> Self {
        Self {
            output_port,
            user_id,
            user_lookup,
            pesticide_gateway,
            crop_gateway,
        }
    }

    pub fn call(
        &mut self,
        crop_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);

        let crop_entity = match self.crop_gateway.find_by_id(crop_id) {
            Ok(entity) => entity,
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some()
                    || err.downcast_ref::<PolicyPermissionDenied>().is_some()
                {
                    self.output_port.on_not_found();
                    return Ok(());
                }
                return Err(err);
            }
        };

        if assert_edit_allowed_for_masters(user, &crop_entity).is_err() {
            self.output_port.on_not_found();
            return Ok(());
        }

        let filter = pesticide_policy::masters_crop_pesticides_index_filter(&user);
        let pesticides = self
            .pesticide_gateway
            .list_by_crop_id_for_filter(crop_entity.id, &filter)?;
        self.output_port.on_success(pesticides);
        Ok(())
    }
}

#[cfg(test)]
mod interactors_masters_crop_pesticides_index_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pesticide/interactors_masters_crop_pesticides_index_interactor_test.rs"));
}
