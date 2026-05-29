//! Ruby: `Domain::Crop::Interactors::CropLoadMastersAuthorizedCropStageInteractor`

use crate::crop::dtos::{AuthorizedCropStageInCropContext, CropLoadAuthorizedCropStageInput};
use crate::crop::gateways::{CropGateway, CropStageGateway};
use crate::crop::ports::CropLoadedAuthorizationFailurePort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;
use crate::shared::reference_record_authorization;

pub struct CropLoadMastersAuthorizedCropStageInteractor<'a, FP, CG, SG, U> {
    failure_presenter: &'a mut FP,
    user_id: i64,
    crop_gateway: &'a CG,
    crop_stage_gateway: &'a SG,
    user_lookup: &'a U,
}

impl<'a, FP, CG, SG, U> CropLoadMastersAuthorizedCropStageInteractor<'a, FP, CG, SG, U>
where
    FP: CropLoadedAuthorizationFailurePort,
    CG: CropGateway,
    SG: CropStageGateway,
    U: UserLookupGateway,
{
    pub fn new(
        failure_presenter: &'a mut FP,
        user_id: i64,
        crop_gateway: &'a CG,
        crop_stage_gateway: &'a SG,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            failure_presenter,
            user_id,
            crop_gateway,
            crop_stage_gateway,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        input: CropLoadAuthorizedCropStageInput,
    ) -> Result<Option<AuthorizedCropStageInCropContext>, Box<dyn std::error::Error + Send + Sync>>
    {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = crop_policy::record_access_filter(user);

        let crop_entity = match self.crop_gateway.find_by_id(input.crop_id) {
            Ok(e) => e,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.failure_presenter.on_not_found();
                return Ok(None);
            }
            Err(err) => return Err(err),
        };

        let crop_stage_entity = match self.crop_stage_gateway.find_by_id(input.crop_stage_id) {
            Ok(e) => e,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.failure_presenter.on_not_found();
                return Ok(None);
            }
            Err(err) => return Err(err),
        };

        if crop_stage_entity.crop_id != crop_entity.id {
            self.failure_presenter.on_not_found();
            return Ok(None);
        }

        if reference_record_authorization::assert_edit_allowed(&access_filter, &crop_entity)
            .is_err()
        {
            self.failure_presenter.on_not_found();
            return Ok(None);
        }

        Ok(Some(AuthorizedCropStageInCropContext::new(
            crop_entity,
            crop_stage_entity,
        )))
    }
}

#[cfg(test)]
mod interactors_crop_load_masters_authorized_crop_stage_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_load_masters_authorized_crop_stage_interactor_test.rs"));
}
