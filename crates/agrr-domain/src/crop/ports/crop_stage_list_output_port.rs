use crate::crop::dtos::CropStageListOutput;
use crate::shared::dtos::Error;

pub enum CropStageListFailure {
    Error(Error),
}

pub trait CropStageListOutputPort {
    fn on_success(&mut self, output: CropStageListOutput);
    fn on_failure(&mut self, error: CropStageListFailure);
}
