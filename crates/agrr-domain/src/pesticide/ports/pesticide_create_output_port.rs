use crate::pesticide::entities::PesticideEntity;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait PesticideCreateOutputPort {
    fn on_success(&mut self, entity: PesticideEntity);
    fn on_failure(&mut self, error: CreateFailure);
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CreateFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
