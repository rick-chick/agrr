//! User-facing regenerate with authorization.

use crate::crop::dtos::{
    CropBlueprintRegenerateFailure, CropBlueprintRegenerateFailureReason,
    CropRegenerateTaskScheduleBlueprintsInput, MastersCropTaskScheduleBlueprintRegenerateInput,
};
use crate::crop::gateways::CropGateway;
use crate::crop::policies::crop_masters_crop_edit_access;
use crate::crop::ports::{
    CropMastersTaskScheduleBlueprintRegenerateOutputPort,
    CropRegenerateTaskScheduleBlueprintsInputPort,
};
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;

pub struct CropMastersTaskScheduleBlueprintRegenerateInteractor<'a, R, CG, O, U> {
    output_port: &'a mut O,
    regenerate: R,
    crop_gateway: &'a CG,
    user_lookup: &'a U,
}

impl<'a, R, CG, O, U> CropMastersTaskScheduleBlueprintRegenerateInteractor<'a, R, CG, O, U>
where
    R: CropRegenerateTaskScheduleBlueprintsInputPort,
    CG: CropGateway,
    O: CropMastersTaskScheduleBlueprintRegenerateOutputPort,
    U: UserLookupGateway,
{
    pub fn new(
        output_port: &'a mut O,
        regenerate: R,
        crop_gateway: &'a CG,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            regenerate,
            crop_gateway,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        input: MastersCropTaskScheduleBlueprintRegenerateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(input.user_id);
        let access_filter = crop_policy::record_access_filter(user);
        let crop_entity = match self.crop_gateway.find_by_id(input.crop_id) {
            Ok(e) => e,
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.output_port.on_failure(CropBlueprintRegenerateFailure::new(
                    CropBlueprintRegenerateFailureReason::CropNotFound,
                    "Crop not found",
                ));
                return Ok(());
            }
            Err(e) => return Err(e),
        };
        if crop_masters_crop_edit_access::assert_edit(&access_filter, &crop_entity).is_err() {
            self.output_port.on_failure(CropBlueprintRegenerateFailure::new(
                CropBlueprintRegenerateFailureReason::CropNotFound,
                "Crop not found",
            ));
            return Ok(());
        }

        match self
            .regenerate
            .call(CropRegenerateTaskScheduleBlueprintsInput::new(input.crop_id))
        {
            Ok(rows) => {
                self.output_port.on_success(rows);
                Ok(())
            }
            Err(failure) => {
                self.output_port.on_failure(failure);
                Ok(())
            }
        }
    }
}
