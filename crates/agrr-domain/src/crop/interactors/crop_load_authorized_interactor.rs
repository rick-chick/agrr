//! Ruby: `Domain::Crop::Interactors::CropLoadAuthorizedInteractor`
use crate::crop::dtos::{AuthorizedCropLoaded, CropLoadAuthorizedInput};
use crate::crop::gateways::CropGateway;
use crate::crop::ports::CropLoadedAuthorizationFailurePort;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;
use crate::shared::reference_record_authorization;

pub struct CropLoadAuthorizedInteractor<'a, FP, G, U> {
    failure_presenter: &'a mut FP,
    user_id: i64,
    gateway: &'a G,
    user_lookup: &'a U,
}

impl<'a, FP, G, U> CropLoadAuthorizedInteractor<'a, FP, G, U>
where
    FP: CropLoadedAuthorizationFailurePort,
    G: CropGateway,
    U: UserLookupGateway,
{
    pub fn new(failure_presenter: &'a mut FP, user_id: i64, gateway: &'a G, user_lookup: &'a U) -> Self {
        Self { failure_presenter, user_id, gateway, user_lookup }
    }

    pub fn call(&mut self, input: CropLoadAuthorizedInput) -> Result<Option<AuthorizedCropLoaded>, Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = crop_policy::record_access_filter(user);
        let crop_entity = match self.gateway.find_by_id(input.crop_id) {
            Ok(e) => e,
            Err(err) if err.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.failure_presenter.on_not_found();
                return Ok(None);
            }
            Err(err) => return Err(err),
        };
        let auth_result = if input.for_edit {
            reference_record_authorization::assert_edit_allowed(&access_filter, &crop_entity)
        } else {
            reference_record_authorization::assert_view_allowed(&access_filter, &crop_entity)
        };
        if auth_result.is_err() {
            self.failure_presenter.on_permission_denied();
            return Ok(None);
        }
        Ok(Some(AuthorizedCropLoaded::new(crop_entity)))
    }
}

#[cfg(test)]
mod interactors_crop_load_authorized_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_load_authorized_interactor_test.rs"));
}
