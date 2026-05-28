use crate::pesticide::dtos::PesticideDestroyOutput;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait PesticideDestroyOutputPort {
    fn on_success(&mut self, dto: PesticideDestroyOutput);
    fn on_failure(&mut self, error: DestroyFailure);
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DestroyFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
