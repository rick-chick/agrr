use crate::pest::entities::PestEntity;
use crate::shared::dtos::{Error, ReferencableListRow};

pub trait PestListOutputPort {
    fn on_success(&mut self, rows: Vec<ReferencableListRow<PestEntity>>);
    fn on_failure(&mut self, error: ListFailure);
}

#[derive(Debug, Clone)]
pub enum ListFailure {
    Error(Error),
}
