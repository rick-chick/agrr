use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::shared::dtos::{Error, ReferencableListRow};
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait AgriculturalTaskListOutputPort {
    fn on_success(&mut self, rows: Vec<ReferencableListRow<AgriculturalTaskEntity>>);
    fn on_failure(&mut self, error: ListFailure);
}

#[derive(Debug, Clone)]
pub enum ListFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
