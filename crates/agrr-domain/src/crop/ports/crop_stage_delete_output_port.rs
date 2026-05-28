use crate::crop::dtos::CropStageDeleteOutput;
use crate::shared::dtos::Error;

pub enum CropStageDeleteFailure {
    Error(Error),
}

pub trait CropStageDeleteOutputPort {
    fn on_success(&mut self, output: CropStageDeleteOutput);
    fn on_failure(&mut self, error: CropStageDeleteFailure);
}
