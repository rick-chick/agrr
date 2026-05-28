use crate::crop::dtos::CropCreateLimitExceededFailure;
use crate::crop::entities::CropEntity;
use crate::shared::dtos::Error;

#[derive(Debug)]
pub enum CreateFailure {
    LimitExceeded(CropCreateLimitExceededFailure),
    Error(Error),
}

pub trait CropCreateOutputPort {
    fn on_success(&mut self, entity: CropEntity);
    fn on_failure(&mut self, error: CreateFailure);
}
