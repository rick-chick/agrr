use crate::farm::dtos::FarmCreateLimitExceededFailure;
use crate::farm::entities::FarmEntity;
use crate::shared::dtos::Error;

pub trait FarmCreateOutputPort {
    fn on_success(&mut self, entity: FarmEntity);
    fn on_failure(&mut self, error: CreateFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum CreateFailure {
    LimitExceeded(FarmCreateLimitExceededFailure),
    Error(Error),
}
