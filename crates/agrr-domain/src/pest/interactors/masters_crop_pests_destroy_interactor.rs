//! Ruby: `Domain::Pest::Interactors::MastersCropPestsDestroyInteractor`

use crate::pest::gateways::{CropGateway, CropPestGateway, PestGateway};
use crate::pest::ports::MastersCropPestsDestroyOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_nested_pests_access;

pub struct MastersCropPestsDestroyInteractor<'a, O, PG, CG, CPG, U> {
    output_port: &'a mut O,
    user_id: i64,
    user_lookup: &'a U,
    pest_gateway: &'a PG,
    crop_gateway: &'a CG,
    crop_pest_gateway: &'a CPG,
}

impl<'a, O, PG, CG, CPG, U> MastersCropPestsDestroyInteractor<'a, O, PG, CG, CPG, U>
where
    O: MastersCropPestsDestroyOutputPort,
    PG: PestGateway,
    CG: CropGateway,
    CPG: CropPestGateway,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        user_lookup: &'a U,
        pest_gateway: &'a PG,
        crop_gateway: &'a CG,
        crop_pest_gateway: &'a CPG,
    ) -> Self {
        Self {
            output_port,
            user_id,
            user_lookup,
            pest_gateway,
            crop_gateway,
            crop_pest_gateway,
        }
    }

    pub fn call(
        &mut self,
        crop_id: i64,
        pest_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);

        let crop = match self.crop_gateway.find_by_id(crop_id)? {
            Some(crop) => crop,
            None => {
                self.output_port.on_crop_not_found();
                return Ok(());
            }
        };

        if crop_nested_pests_access::assert_allowed(&user, &crop).is_err() {
            self.output_port.on_crop_not_found();
            return Ok(());
        }

        let pest_entity = match self.pest_gateway.find_by_id(pest_id) {
            Ok(entity) => entity,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_pest_not_found();
                return Ok(());
            }
            Err(err) => return Err(err),
        };

        if self
            .crop_pest_gateway
            .find_by_crop_id_and_pest_id(crop_id, pest_entity.id)?
            .is_none()
        {
            self.output_port.on_not_associated();
            return Ok(());
        }

        self.crop_pest_gateway.delete(crop_id, pest_entity.id)?;
        self.output_port.on_success();
        Ok(())
    }
}

#[cfg(test)]
mod interactors_masters_crop_pests_destroy_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/pest/interactors_masters_crop_pests_destroy_interactor_test.rs"));
}
