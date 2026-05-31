//! Ruby: `Domain::Crop::Interactors::MastersThermalRequirementUpdateInteractor`
use crate::crop::dtos::ThermalRequirementUpdateInput;
use crate::crop::gateways::{CropGateway, ThermalRequirementGateway};
use crate::crop::ports::MastersThermalRequirementOutputPort;
use crate::shared::exceptions::{RecordInvalidError, RecordNotFoundError};

pub struct MastersThermalRequirementUpdateInteractor<'a, G, RG, O> {
    output_port: &'a mut O,
    gateway: &'a G,
    requirement_gateway: &'a RG,
}

impl<'a, G, RG, O> MastersThermalRequirementUpdateInteractor<'a, G, RG, O>
where
    G: CropGateway,
    RG: ThermalRequirementGateway,
    O: MastersThermalRequirementOutputPort,
{
    pub fn new(output_port: &'a mut O, gateway: &'a G, requirement_gateway: &'a RG) -> Self {
        Self {
            output_port,
            gateway,
            requirement_gateway,
        }
    }

    pub fn call(&mut self, input: ThermalRequirementUpdateInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        if self.requirement_gateway.find_by_crop_stage_id(input.stage_id)?.is_none() {
            self.output_port.on_not_found();
            return Ok(());
        }
        match self.gateway.update_thermal_requirement(input.stage_id, input) {
            Ok(entity) => {
                self.output_port.on_update_success(entity);
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
mod interactors_masters_thermal_requirement_update_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_masters_thermal_requirement_update_interactor_test.rs"));
}
