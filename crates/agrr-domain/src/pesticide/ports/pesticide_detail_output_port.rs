use crate::pesticide::dtos::PesticideDetailOutput;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait PesticideDetailOutputPort {
    fn on_success(&mut self, dto: PesticideDetailOutput);
    fn on_failure(&mut self, error: DetailFailure);
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DetailFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
