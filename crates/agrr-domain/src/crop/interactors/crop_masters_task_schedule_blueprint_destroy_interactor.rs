use crate::crop::dtos::{
    MastersCropTaskScheduleBlueprintDestroyInput, MastersCropTaskScheduleBlueprintFailure,
    MastersCropTaskScheduleBlueprintFailureReason,
};
use crate::crop::gateways::{CropGateway, CropMastersTaskScheduleBlueprintGateway};
use crate::crop::policies::crop_masters_crop_edit_access;
use crate::crop::ports::CropMastersTaskScheduleBlueprintDestroyOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;

pub struct CropMastersTaskScheduleBlueprintDestroyInteractor<'a, G, BG, O, U> {
    output_port: &'a mut O,
    crop_gateway: &'a G,
    blueprint_gateway: &'a BG,
    user_lookup: &'a U,
}

impl<'a, G, BG, O, U> CropMastersTaskScheduleBlueprintDestroyInteractor<'a, G, BG, O, U>
where
    G: CropGateway,
    BG: CropMastersTaskScheduleBlueprintGateway,
    O: CropMastersTaskScheduleBlueprintDestroyOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        crop_gateway: &'a G,
        blueprint_gateway: &'a BG,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            crop_gateway,
            blueprint_gateway,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        input: MastersCropTaskScheduleBlueprintDestroyInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(input.user_id);
        let access_filter = crop_policy::record_access_filter(user);
        let crop_entity = match self.crop_gateway.find_by_id(input.crop_id) {
            Ok(e) => e,
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(MastersCropTaskScheduleBlueprintFailure::new(
                    MastersCropTaskScheduleBlueprintFailureReason::CropNotFound,
                ));
                return Ok(());
            }
            Err(e) => return Err(e),
        };
        if crop_masters_crop_edit_access::assert_edit(&access_filter, &crop_entity).is_err() {
            self.output_port.on_failure(MastersCropTaskScheduleBlueprintFailure::new(
                MastersCropTaskScheduleBlueprintFailureReason::CropNotFound,
            ));
            return Ok(());
        }
        match self
            .blueprint_gateway
            .delete_by_id(input.crop_id, input.blueprint_id)
        {
            Ok(()) => {
                self.output_port.on_success();
                Ok(())
            }
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(MastersCropTaskScheduleBlueprintFailure::new(
                    MastersCropTaskScheduleBlueprintFailureReason::BlueprintNotFound,
                ));
                Ok(())
            }
            Err(e) => Err(e),
        }
    }
}
