use crate::crop::dtos::{
    MastersCropTaskScheduleBlueprint, MastersCropTaskScheduleBlueprintFailure,
};

pub trait CropMastersTaskScheduleBlueprintUpdateOutputPort {
    fn on_success(&mut self, row: MastersCropTaskScheduleBlueprint);
    fn on_failure(&mut self, failure: MastersCropTaskScheduleBlueprintFailure);
}
