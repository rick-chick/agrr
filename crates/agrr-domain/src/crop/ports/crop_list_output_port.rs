use crate::crop::entities::CropEntity;
use crate::shared::dtos::{Error, ReferencableListRow};

#[derive(Debug)]
pub enum ListFailure {
    Error(Error),
}

pub trait CropListOutputPort {
    fn on_success(&mut self, rows: Vec<ReferencableListRow<CropEntity>>);
    fn on_failure(&mut self, error: ListFailure);
}
