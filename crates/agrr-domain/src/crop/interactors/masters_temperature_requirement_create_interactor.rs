//! Ruby: `Domain::Crop::Interactors::MastersTemperatureRequirementCreateInteractor`
use crate::crop::dtos::TemperatureRequirementUpdateInput;
use crate::crop::gateways::{CropGateway, TemperatureRequirementGateway};
use crate::crop::ports::MastersTemperatureRequirementOutputPort;
use crate::shared::exceptions::RecordInvalidError;

pub struct MastersTemperatureRequirementCreateInteractor<'a, G, RG, O> {
    output_port: &'a mut O,
    gateway: &'a G,
    requirement_gateway: &'a RG,
}

impl<'a, G, RG, O> MastersTemperatureRequirementCreateInteractor<'a, G, RG, O>
where
    G: CropGateway,
    RG: TemperatureRequirementGateway,
    O: MastersTemperatureRequirementOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G, requirement_gateway: &'a RG) -> Self {
        Self {
            output_port,
            gateway,
            requirement_gateway,
        }
    }

    pub fn call(&mut self, input: TemperatureRequirementUpdateInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if self.requirement_gateway.find_by_crop_stage_id(input.stage_id)?.is_some() {
            self.output_port.on_already_exists();
            return Ok(());
        }
        match self.gateway.create_temperature_requirement(input.stage_id, input) {
            Ok(entity) => {
                self.output_port.on_create_success(entity);
                Ok(())
            }
            Err(err) => {
                if let Some(e) = err.downcast_ref::<RecordInvalidError>() {
                    self.output_port.on_validation_errors(e.flatten_error_messages());
                    Ok(())
                } else {
                    Err(err)
                }
            }
        }
    }

}
