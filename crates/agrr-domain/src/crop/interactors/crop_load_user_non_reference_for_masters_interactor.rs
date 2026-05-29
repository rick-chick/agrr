//! Ruby: `Domain::Crop::Interactors::CropLoadUserNonReferenceForMastersInteractor`
use crate::crop::entities::CropEntity;
use crate::crop::gateways::CropGateway;
use crate::crop::policies::crop_masters_nested_access;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;

pub trait CropLoadUserNonReferenceForMastersOutputPort {
    fn on_success(&mut self, crop: CropEntity);
    fn on_not_found(&mut self);
}

pub struct CropLoadUserNonReferenceForMastersInteractor<'a, O, G, U> {
    output_port: &'a mut O, gateway: &'a G, user_id: i64, user_lookup: &'a U,
}
impl<'a, O, G, U> CropLoadUserNonReferenceForMastersInteractor<'a, O, G, U>
where O: CropLoadUserNonReferenceForMastersOutputPort, G: CropGateway, U: UserLookupGateway,
{
    pub fn new(output_port: &'a mut O, user_id: i64, gateway: &'a G, user_lookup: &'a U) -> Self {
        Self { output_port, gateway, user_id, user_lookup }
    }
    pub fn call(&mut self, crop_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let crop_entity = match self.gateway.find_by_id(crop_id) {
            Ok(e) => e,
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_not_found(); return Ok(());
            }
            Err(e) => return Err(e),
        };
        if crop_masters_nested_access::assert_edit_allowed_for_masters(&user, &crop_entity).is_err() {
            self.output_port.on_not_found(); return Ok(());
        }
        self.output_port.on_success(crop_entity);
        Ok(())
    }
}

#[cfg(test)]
mod interactors_crop_load_user_non_reference_for_masters_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_load_user_non_reference_for_masters_interactor_test.rs"));
}
