//! Ruby: `Domain::Crop::Interactors::CropStageCreateInteractor`

use crate::crop::dtos::{CropStageCreateInput, CropStageOutput};
use crate::crop::gateways::CropGateway;
use crate::crop::ports::{CropStageCreateFailure, CropStageCreateOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;

pub struct CropStageCreateInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
}

impl<'a, G, O> CropStageCreateInteractor<'a, G, O>
where
    G: CropGateway,
    O: CropStageCreateOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self {
        Self { output_port, gateway }
    }

    pub fn call(
        &mut self,
        input: CropStageCreateInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.gateway.create_crop_stage(input) {
            Ok(stage) => {
                self.output_port.on_success(CropStageOutput::new(stage));
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    self.output_port.on_failure(CropStageCreateFailure::Error(Error::new(
                        record_invalid.to_string(),
                    )));
                    Ok(())
                }
                Err(err) => Err(err),
            },
        }
    }
}

#[cfg(test)]
mod interactors_crop_stage_create_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_stage_create_interactor_test.rs"));
}
