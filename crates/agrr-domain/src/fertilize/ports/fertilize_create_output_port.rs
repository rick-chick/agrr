use crate::fertilize::entities::FertilizeEntity;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait FertilizeCreateOutputPort {
    fn on_success(&mut self, entity: FertilizeEntity);
    fn on_failure(&mut self, error: CreateFailure);
}

#[derive(Debug, Clone)]
pub enum CreateFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
