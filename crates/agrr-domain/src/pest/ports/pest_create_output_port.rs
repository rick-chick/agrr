use crate::pest::entities::PestEntity;
use crate::shared::dtos::Error;

pub trait PestCreateOutputPort {
    fn on_success(&mut self, entity: PestEntity);
    fn on_failure(&mut self, error: CreateFailure);
}

#[derive(Debug, Clone)]
pub enum CreateFailure {
    Error(Error),
}
