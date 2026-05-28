use crate::farm::entities::FarmEntity;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait FarmUpdateOutputPort {
    fn on_success(&mut self, entity: FarmEntity);
    fn on_failure(&mut self, error: UpdateFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum UpdateFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
