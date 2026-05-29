//! Ruby: `Domain::Crop::Interactors::CropFindUserNonReferenceRecordInteractor`

use crate::crop::entities::CropEntity;
use crate::crop::gateways::CropGateway;
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::gateways::UserLookupGateway;
use crate::shared::policies::crop_policy;
use crate::shared::ports::logger_port::LoggerPort;
use crate::shared::reference_record_authorization;

pub trait CropFindUserNonReferenceRecordOutputPort {
    fn on_success(&mut self, entity: CropEntity);
    fn on_failure(&mut self, error: Error);
}

pub struct CropFindUserNonReferenceRecordInteractor<'a, G, O, U, L> {
    output_port: &'a mut O,
    gateway: &'a G,
    user_id: i64,
    logger: &'a L,
    user_lookup: &'a U,
}

impl<'a, G, O, U, L> CropFindUserNonReferenceRecordInteractor<'a, G, O, U, L>
where
    G: CropGateway,
    O: CropFindUserNonReferenceRecordOutputPort,
    U: UserLookupGateway,
    L: LoggerPort,
{
    pub fn new(
        output_port: &'a mut O,
        user_id: i64,
        gateway: &'a G,
        logger: &'a L,
        user_lookup: &'a U,
    ) -> Self {
        Self {
            output_port,
            gateway,
            user_id,
            logger,
            user_lookup,
        }
    }

    pub fn call(
        &mut self,
        crop_id: i64,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let user = self.user_lookup.find(self.user_id);
        let access_filter = crop_policy::record_access_filter(user);

        let crop_entity = match self.gateway.find_by_id(crop_id) {
            Ok(entity) => entity,
            Err(err) => {
                self.logger.warn(&format!(
                    "[CropFindUserNonReferenceRecordInteractor] {err}"
                ));
                if err.downcast_ref::<RecordNotFoundError>().is_some()
                    || err.downcast_ref::<RecordInvalidError>().is_some()
                {
                    self.output_port.on_failure(Error::new(err.to_string()));
                    return Ok(());
                }
                return Err(err);
            }
        };

        if reference_record_authorization::assert_edit_allowed(&access_filter, &crop_entity).is_err()
        {
            self.logger.warn(
                "[CropFindUserNonReferenceRecordInteractor] policy permission denied",
            );
            self.output_port
                .on_failure(Error::new("policy permission denied"));
            return Ok(());
        }

        self.output_port.on_success(crop_entity);
        Ok(())
    }
}

#[cfg(test)]
mod interactors_crop_find_user_non_reference_record_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_find_user_non_reference_record_interactor_test.rs"));
}
