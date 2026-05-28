use crate::pesticide::entities::PesticideEntity;
use crate::shared::dtos::{Error, ReferencableListRow};
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait PesticideListOutputPort {
    fn on_success(&mut self, rows: Vec<ReferencableListRow<PesticideEntity>>);
    fn on_failure(&mut self, error: ListFailure);
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ListFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
