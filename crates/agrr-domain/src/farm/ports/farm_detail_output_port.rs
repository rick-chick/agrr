use crate::farm::dtos::FarmDetailOutput;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait FarmDetailOutputPort {
    fn on_success(&mut self, output: FarmDetailOutput);
    fn on_failure(&mut self, error: DetailFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum DetailFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
