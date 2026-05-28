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
mod tests {
    use super::*;
    use crate::crop::entities::NutrientRequirementEntity;

    struct StubGw { found: bool }
    impl NutrientRequirementGateway for StubGw {
        fn find_by_crop_stage_id(&self, _: i64) -> Result<Option<NutrientRequirementEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(if self.found { Some(NutrientRequirementEntity::new(1, 9).unwrap()) } else { None })
        }
    }
    struct Spy { event: Option<&'static str> }
    impl MastersNutrientRequirementOutputPort for Spy {
        fn on_show_success(&mut self, _: NutrientRequirementEntity) { self.event = Some("show"); }
        fn on_create_success(&mut self, _: NutrientRequirementEntity) {}
        fn on_update_success(&mut self, _: NutrientRequirementEntity) {}
        fn on_destroy_success(&mut self) {}
        fn on_not_found(&mut self) { self.event = Some("not_found"); }
        fn on_already_exists(&mut self) {}
        fn on_validation_errors(&mut self, _: Vec<String>) {}
    }

    // Ruby: test "renders show success when requirement exists"
    #[test]
    fn renders_show_success_when_requirement_exists() {
        let gw = StubGw { found: true };
        let mut out = Spy { event: None };
        let mut i = MastersNutrientRequirementShowInteractor::new(&mut out, &gw);
        i.call(CropStageDetailInput { crop_stage_id: 9 }).unwrap();
        assert_eq!(out.event, Some("show"));
    }

    // Ruby: test "renders not found when requirement missing"
    #[test]
    fn renders_not_found_when_requirement_missing() {
        let gw = StubGw { found: false };
        let mut out = Spy { event: None };
        let mut i = MastersNutrientRequirementShowInteractor::new(&mut out, &gw);
        i.call(CropStageDetailInput { crop_stage_id: 9 }).unwrap();
        assert_eq!(out.event, Some("not_found"));
    }
}
