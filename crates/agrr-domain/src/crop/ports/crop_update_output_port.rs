use crate::crop::entities::CropEntity;
use crate::shared::dtos::{Error, ReferenceFlagChangeDeniedFailure};
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub enum UpdateFailure {
    Policy(PolicyPermissionDenied),
    ReferenceFlagChangeDenied(ReferenceFlagChangeDeniedFailure),
    Error(Error),
}

pub trait CropUpdateOutputPort {
    fn on_success(&mut self, entity: CropEntity);
    fn on_failure(&mut self, error: UpdateFailure);
}
