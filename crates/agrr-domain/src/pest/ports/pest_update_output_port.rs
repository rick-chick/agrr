use crate::pest::entities::PestEntity;
use crate::shared::dtos::{Error, ReferenceFlagChangeDeniedFailure};
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait PestUpdateOutputPort {
    fn on_success(&mut self, entity: PestEntity);
    fn on_failure(&mut self, error: UpdateFailure);
}

#[derive(Debug, Clone)]
pub enum UpdateFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
    ReferenceFlagChange(ReferenceFlagChangeDeniedFailure),
}
