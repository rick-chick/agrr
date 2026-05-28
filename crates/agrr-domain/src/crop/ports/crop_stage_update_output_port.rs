use crate::crop::dtos::CropStageOutput;
use crate::shared::dtos::Error;

pub enum CropStageUpdateFailure {
    Error(Error),
}

pub trait CropStageUpdateOutputPort {
    fn on_success(&mut self, output: CropStageOutput);
    fn on_failure(&mut self, error: CropStageUpdateFailure);
}
