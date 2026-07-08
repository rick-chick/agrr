use crate::crop::dtos::{
    MastersCropTaskScheduleBlueprint, MastersCropTaskScheduleBlueprintFailure,
};

pub trait CropMastersTaskScheduleBlueprintIndexOutputPort {
    fn on_success(&mut self, rows: Vec<MastersCropTaskScheduleBlueprint>);
    fn on_failure(&mut self, failure: MastersCropTaskScheduleBlueprintFailure);
}
