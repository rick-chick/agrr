use crate::agricultural_task::entities::AgriculturalTaskEntity;
use crate::shared::dtos::{Error, ReferenceFlagChangeDeniedFailure};
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait AgriculturalTaskUpdateOutputPort {
    fn on_success(&mut self, entity: AgriculturalTaskEntity);
    fn on_failure(&mut self, error: UpdateFailure);
}

#[derive(Debug, Clone)]
pub enum UpdateFailure {
    Policy(PolicyPermissionDenied),
    ReferenceFlag(ReferenceFlagChangeDeniedFailure),
    Error(Error),
}
