//! Ruby: `Domain::Crop::Interactors::CropStageDetailInteractor`

use crate::crop::dtos::{CropStageDetailInput, CropStageOutput};
use crate::crop::gateways::CropStageGateway;
use crate::crop::ports::{CropStageDetailFailure, CropStageDetailOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;

pub struct CropStageDetailInteractor<'a, SG, O> {
    output_port: &'a mut O,
    crop_stage_gateway: &'a SG,
}

impl<'a, SG, O> CropStageDetailInteractor<'a, SG, O>
where
    SG: CropStageGateway,
    O: CropStageDetailOutputPort,
{
    pub fn new(output_port: &'a mut O, crop_stage_gateway: &'a SG) -> Self {
        Self {
            output_port,
            crop_stage_gateway,
        }
    }

    pub fn call(
        &mut self,
        input: CropStageDetailInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.crop_stage_gateway.find_by_id(input.crop_stage_id) {
            Ok(stage) => {
                self.output_port.on_success(CropStageOutput::new(stage));
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    self.output_port.on_failure(CropStageDetailFailure::Error(Error::new(
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
mod interactors_crop_stage_detail_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_stage_detail_interactor_test.rs"));
}
