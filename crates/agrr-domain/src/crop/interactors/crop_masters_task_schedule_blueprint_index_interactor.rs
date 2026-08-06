//! Ruby: `Domain::Crop::Interactors::CropMastersTaskScheduleBlueprintIndexInteractor`

use crate::crop::dtos::{
    MastersCropTaskScheduleBlueprintFailure, MastersCropTaskScheduleBlueprintFailureReason,
    MastersCropTaskScheduleBlueprintIndexInput,
};
use crate::crop::gateways::{CropGateway, CropMastersTaskScheduleBlueprintGateway};
use crate::crop::policies::crop_masters_crop_edit_access;
use crate::crop::ports::CropMastersTaskScheduleBlueprintIndexOutputPort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::{UserLookupGateway, UserOrganizationScopeGateway};
use crate::shared::policies::crop_policy;

pub struct CropMastersTaskScheduleBlueprintIndexInteractor<'a, G, BG, O, U, S> {
    output_port: &'a mut O,
    crop_gateway: &'a G,
    blueprint_gateway: &'a BG,
    user_lookup: &'a U,
    scope_gateway: &'a S,
}

impl<'a, G, BG, O, U, S> CropMastersTaskScheduleBlueprintIndexInteractor<'a, G, BG, O, U, S>
where
    G: CropGateway,
    BG: CropMastersTaskScheduleBlueprintGateway,
    O: CropMastersTaskScheduleBlueprintIndexOutputPort,
    U: UserLookupGateway,
    S: UserOrganizationScopeGateway,
{
    pub fn new(
        output_port: &'a mut O,
        crop_gateway: &'a G,
        blueprint_gateway: &'a BG,
        user_lookup: &'a U,
        scope_gateway: &'a S) -> Self {
        Self {
            output_port,
            crop_gateway,
            blueprint_gateway,
            user_lookup,
            scope_gateway,
        }
    }

    pub fn call(
        &mut self,
        input: MastersCropTaskScheduleBlueprintIndexInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(input.user_id);
        let access_filter = crop_policy::record_access_filter_for_user(self.scope_gateway, user)?;
        let failure = MastersCropTaskScheduleBlueprintFailure::new(
            MastersCropTaskScheduleBlueprintFailureReason::CropNotFound,
        );
        let crop_entity = match self.crop_gateway.find_by_id(input.crop_id) {
            Ok(e) => e,
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(failure);
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
        let rows = self.blueprint_gateway.list_by_crop_id(input.crop_id)?;
        self.output_port.on_success(rows);
        Ok(())
    }
}
