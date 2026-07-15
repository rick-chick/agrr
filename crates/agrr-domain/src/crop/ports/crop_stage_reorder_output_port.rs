use crate::crop::dtos::CropStageListOutput;
use crate::shared::dtos::Error;

pub enum CropStageReorderFailure {
    Error(Error),
    NotFound,
}

pub trait CropStageReorderOutputPort {
    fn on_success(&mut self, output: CropStageListOutput);
    fn on_failure(&mut self, error: CropStageReorderFailure);
}
