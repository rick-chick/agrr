//! Ruby: `Domain::Crop::Interactors::MastersNutrientRequirementDestroyInteractor`
use crate::crop::dtos::CropStageDetailInput;
use crate::crop::gateways::CropGateway;
use crate::crop::ports::MastersNutrientRequirementOutputPort;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};

pub struct MastersNutrientRequirementDestroyInteractor<'a, G, O> {
    output_port: &'a mut O,
    gateway: &'a G,
}

impl<'a, G, O> MastersNutrientRequirementDestroyInteractor<'a, G, O>
where
    G: CropGateway,
    O: MastersNutrientRequirementOutputPort,
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
        match self.gateway.delete_nutrient_requirement(input.crop_stage_id) {
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
