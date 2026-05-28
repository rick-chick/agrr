use crate::crop::dtos::CropStageOutput;
use crate::shared::dtos::Error;

#[derive(Debug)]
pub enum CropStageCreateFailure {
    Error(Error),
}

pub trait CropStageCreateOutputPort {
    fn on_success(&mut self, output: CropStageOutput);
    fn on_failure(&mut self, error: CropStageCreateFailure);
}
