//! Ruby: `Domain::Crop::Interactors::MastersSunshineRequirementDestroyInteractor`
use crate::crop::dtos::CropStageDetailInput;
use crate::crop::gateways::CropGateway;
use crate::crop::ports::MastersSunshineRequirementOutputPort;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};

pub struct MastersSunshineRequirementDestroyInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
}

impl<'a, G, O> MastersSunshineRequirementDestroyInteractor<'a, G, O>
where
    G: CropGateway,
    O: MastersSunshineRequirementOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G) -> Self {
        Self {
            output_port,
            gateway,
        }
    }

    pub fn call(
        &mut self,
        input: CropStageDetailInput,
    ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.gateway.delete_sunshine_requirement(input.crop_stage_id) {
            Ok(()) => {
                self.output_port.on_destroy_success();
                Ok(())
            }
            Err(err) => {
                if err.downcast_ref::<RecordNotFoundError>().is_some() {
                    self.output_port.on_not_found();
                    Ok(())
                } else if let Some(e) = err.downcast_ref::<RecordInvalidError>() {
                    self.output_port.on_validation_errors(e.flatten_error_messages());
                    Ok(())
                } else {
                    Err(err)
                }
            }
        }
    }
}

#[cfg(test)]
mod interactors_masters_sunshine_requirement_destroy_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_masters_sunshine_requirement_destroy_interactor_test.rs"));
}
