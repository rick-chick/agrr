use crate::crop::dtos::{
    CropBlueprintRegenerateFailure, MastersCropTaskScheduleBlueprint,
};

pub trait CropMastersTaskScheduleBlueprintRegenerateOutputPort {
    fn on_success(&mut self, rows: Vec<MastersCropTaskScheduleBlueprint>);
    fn on_failure(&mut self, failure: CropBlueprintRegenerateFailure);
}
