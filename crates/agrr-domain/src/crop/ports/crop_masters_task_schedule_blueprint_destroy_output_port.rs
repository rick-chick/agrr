use crate::crop::dtos::MastersCropTaskScheduleBlueprintFailure;

pub trait CropMastersTaskScheduleBlueprintDestroyOutputPort {
    fn on_success(&mut self);
    fn on_failure(&mut self, failure: MastersCropTaskScheduleBlueprintFailure);
}
