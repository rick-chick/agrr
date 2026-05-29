//! Ruby: `Domain::Crop::Interactors::CropMastersTaskTemplateDestroyInteractor`
use crate::crop::dtos::{MastersCropTaskTemplateDestroyInput, MastersCropTaskTemplateMastersFailure, MastersCropTaskTemplateMastersFailureReason};
use crate::crop::gateways::CropGateway;
use crate::crop::policies::crop_masters_crop_edit_access;
use crate::crop::ports::CropMastersTaskTemplateDestroyOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;

pub struct CropMastersTaskTemplateDestroyInteractor<'a, G, O, U> { output_port: &'a mut O, gateway: &'a G, user_lookup: &'a U }
impl<'a, G, O, U> CropMastersTaskTemplateDestroyInteractor<'a, G, O, U>
where G: CropGateway, O: CropMastersTaskTemplateDestroyOutputPort, U: UserLookupGateway,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G, user_lookup: &'a U) -> Self { Self { output_port, gateway, user_lookup } }
    pub fn call(&mut self, input: MastersCropTaskTemplateDestroyInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(input.user_id);
        let access_filter = crop_policy::record_access_filter(user);
        let failure = MastersCropTaskTemplateMastersFailure::new(MastersCropTaskTemplateMastersFailureReason::CropNotFound);
        let crop_entity = match self.gateway.find_by_id(input.crop_id) {
            Ok(e) => e,
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => { self.output_port.on_failure(failure); return Ok(()); }
            Err(e) => return Err(e),
        };
        if crop_masters_crop_edit_access::assert_edit(&access_filter, &crop_entity).is_err() {
            self.output_port.on_failure(MastersCropTaskTemplateMastersFailure::new(MastersCropTaskTemplateMastersFailureReason::CropNotFound));
            return Ok(());
        }
        match self.gateway.delete_masters_crop_task_template(input.crop_id, input.template_id) {
            Ok(()) => { self.output_port.on_success(); Ok(()) }
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(MastersCropTaskTemplateMastersFailure::new(MastersCropTaskTemplateMastersFailureReason::AssociationNotFound));
                Ok(())
            }
            Err(e) => Err(e),
        }
    }
}

#[cfg(test)]
mod interactors_crop_masters_task_template_destroy_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_masters_task_template_destroy_interactor_test.rs"));
}
