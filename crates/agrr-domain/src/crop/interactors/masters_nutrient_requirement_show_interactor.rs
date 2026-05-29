//! Ruby: `Domain::Crop::Interactors::MastersNutrientRequirementShowInteractor`
use crate::crop::dtos::CropStageDetailInput;
use crate::crop::gateways::NutrientRequirementGateway;
use crate::crop::ports::MastersNutrientRequirementOutputPort;

pub struct MastersNutrientRequirementShowInteractor<'a, RG, O> {
    output_port: &'a mut O,
    requirement_gateway: &'a RG,
}

impl<'a, RG, O> MastersNutrientRequirementShowInteractor<'a, RG, O>
where
    RG: NutrientRequirementGateway,
    O: MastersNutrientRequirementOutputPort,
{
    pub fn new(output_port: &'a mut O, requirement_gateway: &'a RG) -> Self {
        Self { output_port, requirement_gateway }
    }

    pub fn call(&mut self, input: CropStageDetailInput) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
        match self.requirement_gateway.find_by_crop_stage_id(input.crop_stage_id)? {
            Some(entity) => self.output_port.on_show_success(entity),
            None => self.output_port.on_not_found(),
        }
        Ok(())
    }
}

#[cfg(test)]
mod interactors_masters_nutrient_requirement_show_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/crop/interactors_masters_nutrient_requirement_show_interactor_test.rs"));
}
