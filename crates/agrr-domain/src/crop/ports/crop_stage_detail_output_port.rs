use crate::crop::dtos::CropStageOutput;
use crate::shared::dtos::Error;

pub enum CropStageDetailFailure {
    Error(Error),
}

pub trait CropStageDetailOutputPort {
    fn on_success(&mut self, output: CropStageOutput);
    fn on_failure(&mut self, error: CropStageDetailFailure);
}
