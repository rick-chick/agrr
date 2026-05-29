//! Ruby: `Domain::Crop::Interactors::CropStageDeleteInteractor`
use crate::crop::dtos::{CropStageDeleteInput, CropStageDeleteOutput};
use crate::crop::gateways::CropGateway;
use crate::crop::ports::{CropStageDeleteFailure, CropStageDeleteOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;

pub struct CropStageDeleteInteractor<'a, G, O> { output_port: &'a mut O, gateway: &'a G }
impl<'a, G, O> CropStageDeleteInteractor<'a, G, O>
where G: CropGateway, O: CropStageDeleteOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self { Self { output_port, gateway } }
    pub fn call(&mut self, input: CropStageDeleteInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.gateway.delete_crop_stage(input.crop_stage_id) {
            Ok(()) => {
                self.output_port.on_success(CropStageDeleteOutput {
                    crop_stage_id: input.crop_stage_id,
                });
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(e) => { self.output_port.on_failure(CropStageDeleteFailure::Error(Error::new(e.to_string()))); Ok(()) }
                Err(err) => Err(err),
            },
        }
    }
}

#[cfg(test)]
mod interactors_crop_stage_delete_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_stage_delete_interactor_test.rs"));
}
