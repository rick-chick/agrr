use crate::pesticide::entities::PesticideEntity;
use crate::shared::dtos::{Error, ReferenceFlagChangeDeniedFailure};
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait PesticideUpdateOutputPort {
    fn on_success(&mut self, entity: PesticideEntity);
    fn on_failure(&mut self, error: UpdateFailure);
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum UpdateFailure {
    Policy(PolicyPermissionDenied),
    ReferenceFlag(ReferenceFlagChangeDeniedFailure),
    Error(Error),
}
