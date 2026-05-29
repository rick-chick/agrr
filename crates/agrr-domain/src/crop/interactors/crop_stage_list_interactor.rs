//! Ruby: `Domain::Crop::Interactors::CropStageListInteractor`

use crate::crop::dtos::{CropStageListInput, CropStageListOutput};
use crate::crop::gateways::CropGateway;
use crate::crop::ports::{CropStageListFailure, CropStageListOutputPort};
use crate::shared::dtos::Error;
use crate::shared::exceptions::RecordInvalidError;

pub struct CropStageListInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
}

impl<'a, G, O> CropStageListInteractor<'a, G, O>
where
    G: CropGateway,
    O: CropStageListOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self {
        Self { output_port, gateway }
    }

    pub fn call(
        &mut self,
        input: CropStageListInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.gateway.list_by_crop_id(input.crop_id) {
            Ok(stages) => {
                self.output_port.on_success(CropStageListOutput { stages });
                Ok(())
            }
            Err(err) => match err.downcast::<RecordInvalidError>() {
                Ok(record_invalid) => {
                    self.output_port.on_failure(CropStageListFailure::Error(Error::new(
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
mod interactors_crop_stage_list_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_crop_stage_list_interactor_test.rs"));
}
