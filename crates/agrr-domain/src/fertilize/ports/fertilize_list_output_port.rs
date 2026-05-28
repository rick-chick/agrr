use crate::fertilize::entities::FertilizeEntity;
use crate::shared::dtos::ReferencableListRow;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;
use crate::shared::dtos::Error;

pub trait FertilizeListOutputPort {
    fn on_success(&mut self, rows: Vec<ReferencableListRow<FertilizeEntity>>);
    fn on_failure(&mut self, error: ListFailure);
}

#[derive(Debug, Clone)]
pub enum ListFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
