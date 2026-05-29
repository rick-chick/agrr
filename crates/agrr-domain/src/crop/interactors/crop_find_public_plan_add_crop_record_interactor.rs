//! Ruby: `Domain::Crop::Interactors::CropFindPublicPlanAddCropRecordInteractor`
use crate::crop::entities::CropEntity;
use crate::crop::gateways::CropGateway;
use crate::crop::policies::crop_reference_record_policy;
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordNotFoundError;
use crate::shared::ports::logger_port::LoggerPort;

pub trait CropFindPublicPlanAddCropRecordOutputPort {
    fn on_success(&mut self, crop: CropEntity);
    fn on_failure(&mut self, error: Error);
}

pub struct CropFindPublicPlanAddCropRecordInteractor<'a, O, G, L> {
    output_port: &'a mut O, gateway: &'a G, logger: &'a L,
}
impl<'a, O, G, L> CropFindPublicPlanAddCropRecordInteractor<'a, O, G, L>
where O: CropFindPublicPlanAddCropRecordOutputPort, G: CropGateway, L: LoggerPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G, logger: &'a L) -> Self { Self { output_port, gateway, logger } }
    pub fn call(&mut self, crop_id: i64) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if crop_id == 0 {
            self.logger.warn("[CropFindPublicPlanAddCropRecordInteractor] reference crop not found");
            self.output_port.on_failure(Error::new("Crop not found"));
            return Ok(());
        }
        let crop = match self.gateway.find_by_id(crop_id) {
            Ok(c) => c,
            Err(e) if e.downcast_ref::<RecordNotFoundError>().is_some() => {
                self.logger.warn("[CropFindPublicPlanAddCropRecordInteractor] reference crop not found");
                self.output_port.on_failure(Error::new("Crop not found")); return Ok(());
            }
            Err(e) => return Err(e),
        };
        if crop_reference_record_policy::visible_for_public_plan_add_crop(&crop) {
            self.output_port.on_success(crop);
        } else {
            self.logger.warn("[CropFindPublicPlanAddCropRecordInteractor] reference crop not found");
            self.output_port.on_failure(Error::new("Crop not found"));
        }
        Ok(())
    }
}

#[cfg(test)]
mod interactors_crop_find_public_plan_add_crop_record_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_find_public_plan_add_crop_record_interactor_test.rs"));
}
