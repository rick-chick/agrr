//! Ruby parity: private plan add_crop accepts reference crops (public flow) and user-owned crops.

use crate::crop::entities::CropEntity;
use crate::crop::gateways::CropGateway;
use crate::crop::policies::crop_reference_record_policy;
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;
use crate::shared::ports::logger_port::LoggerPort;
use crate::shared::reference_record_authorization;

pub trait CropFindPrivatePlanAddCropRecordOutputPort {
    fn on_success(&mut self, crop: CropEntity);
    fn on_failure(&mut self, error: Error);
}

pub struct CropFindPrivatePlanAddCropRecordInteractor<'a, O, G, U, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    user_lookup: &'a U,
    logger: &'a L,
}

impl<'a, O, G, U, L> CropFindPrivatePlanAddCropRecordInteractor<'a, O, G, U, L>
where
    O: CropFindPrivatePlanAddCropRecordOutputPort,
    G: CropGateway,
    U: UserLookupGateway,
    L: LoggerPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        user_lookup: &'a U,
        logger: &'a L,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            user_lookup,
            logger,
        }
    }

    pub fn call(&mut self, crop_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if crop_id == 0 {
            self.logger
                .warn("[CropFindPrivatePlanAddCropRecordInteractor] crop not found");
            self.output_port.on_failure(Error::new("Crop not found"));
            return Ok(());
        }

        let crop = match self.gateway.find_by_id(crop_id) {
            Ok(c) => c,
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.logger
                    .warn("[CropFindPrivatePlanAddCropRecordInteractor] crop not found");
                self.output_port.on_failure(Error::new("Crop not found"));
                return Ok(());
            }
            Err(e) => return Err(e),
        };

        if crop_reference_record_policy::visible_for_public_plan_add_crop(&crop) {
            self.output_port.on_success(crop);
            return Ok(());
        }

        let user = self.user_lookup.find(self.user_id);
        let access_filter = crop_policy::record_access_filter(user);
        if reference_record_authorization::assert_edit_allowed(&access_filter, &crop).is_err() {
            self.logger.warn(
                "[CropFindPrivatePlanAddCropRecordInteractor] policy permission denied",
            );
            self.output_port
                .on_failure(Error::new("policy permission denied"));
            return Ok(());
        }

        self.output_port.on_success(crop);
        Ok(())
    }
}

#[cfg(test)]
mod interactors_crop_find_private_plan_add_crop_record_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/crop/interactors_crop_find_private_plan_add_crop_record_interactor_test.rs"
    ));
}
