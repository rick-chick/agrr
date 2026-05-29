//! Ruby: `Domain::Crop::Interactors::CropMastersTaskTemplateUpdateInteractor`
use crate::crop::dtos::{MastersCropTaskTemplateMastersFailure, MastersCropTaskTemplateMastersFailureReason, MastersCropTaskTemplateUpdateInput};
use crate::crop::gateways::{CropGateway, UpdateMastersCropTaskTemplateOutcome};
use crate::crop::policies::crop_masters_crop_edit_access;
use crate::crop::ports::CropMastersTaskTemplateUpdateOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;

pub struct CropMastersTaskTemplateUpdateInteractor<'a, G, O, U> {
    output_port: &'a mut O, gateway: &'a G, user_lookup: &'a U,
}
impl<'a, G, O, U> CropMastersTaskTemplateUpdateInteractor<'a, G, O, U>
where G: CropGateway, O: CropMastersTaskTemplateUpdateOutputPort, U: UserLookupGateway,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G, user_lookup: &'a U) -> Self { Self { output_port, gateway, user_lookup } }
    pub fn call(&mut self, input: MastersCropTaskTemplateUpdateInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
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
        match self.gateway.update_masters_crop_task_template_for_api(input.crop_id, input.template_id, input.attributes) {
            Ok(UpdateMastersCropTaskTemplateOutcome::Ok { row }) => { self.output_port.on_success(row); Ok(()) }
            Ok(UpdateMastersCropTaskTemplateOutcome::ValidationFailed { errors }) => {
                self.output_port.on_failure(MastersCropTaskTemplateMastersFailure::validation_failed(errors));
                Ok(())
            }
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(MastersCropTaskTemplateMastersFailure::new(MastersCropTaskTemplateMastersFailureReason::AssociationNotFound));
                Ok(())
            }
            Err(e) => Err(e),
        }
    }
}

#[cfg(test)]
mod interactors_crop_masters_task_template_update_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_masters_task_template_update_interactor_test.rs"));
}
