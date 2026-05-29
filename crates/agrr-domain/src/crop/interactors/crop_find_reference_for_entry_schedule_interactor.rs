//! Ruby: `Domain::Crop::Interactors::CropFindReferenceForEntryScheduleInteractor`
use crate::crop::dtos::CropFindReferenceForEntryScheduleInput;
use crate::crop::entities::CropEntity;
use crate::crop::gateways::CropGateway;
use crate::crop::policies::crop_reference_record_policy;
use crate::shared::dtos::Error;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};
use crate::shared::ports::logger_port::LoggerPort;

pub trait CropFindReferenceForEntryScheduleOutputPort {
    fn on_success(&mut self, crop: CropEntity);
    fn on_failure(&mut self, error: Error);
}

pub struct CropFindReferenceForEntryScheduleInteractor<'a, O, G, L> {
    output_port: &'a mut O, gateway: &'a G, logger: &'a L,
}
impl<'a, O, G, L> CropFindReferenceForEntryScheduleInteractor<'a, O, G, L>
where O: CropFindReferenceForEntryScheduleOutputPort, G: CropGateway, L: LoggerPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G, logger: &'a L) -> Self { Self { output_port, gateway, logger } }
    pub fn call(&mut self, input: CropFindReferenceForEntryScheduleInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        let crop = match self.gateway.find_crop_record_with_stages(input.crop_id) {
            Ok(c) => c,
            Err(e) => {
                self.logger.warn(&format!("[CropFindReferenceForEntryScheduleInteractor] {e}"));
                if e.downcast_ref::<RecordNotFoundError>().is_some() || e.downcast_ref::<RecordInvalidError>().is_some() {
                    self.output_port.on_failure(Error::new(e.to_string())); return Ok(());
                }
                return Err(e);
            }
        };
        if crop_reference_record_policy::visible_for_entry_schedule(&crop, input.region.as_deref(), crop.region.as_deref()) {
            self.output_port.on_success(crop);
        } else {
            self.logger.warn(&format!("[CropFindReferenceForEntryScheduleInteractor] crop not visible crop_id={}", input.crop_id));
            self.output_port.on_failure(Error::new("Crop not found"));
        }
        Ok(())
    }
}

#[cfg(test)]
mod interactors_crop_find_reference_for_entry_schedule_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_find_reference_for_entry_schedule_interactor_test.rs"));
}
