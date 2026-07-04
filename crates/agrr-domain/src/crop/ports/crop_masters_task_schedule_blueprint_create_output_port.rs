use crate::crop::dtos::{
    MastersCropTaskScheduleBlueprint, MastersCropTaskScheduleBlueprintCreateFailure,
};

pub trait CropMastersTaskScheduleBlueprintCreateOutputPort {
    fn on_success(&mut self, row: MastersCropTaskScheduleBlueprint);
    fn on_failure(&mut self, failure: MastersCropTaskScheduleBlueprintCreateFailure);
}
