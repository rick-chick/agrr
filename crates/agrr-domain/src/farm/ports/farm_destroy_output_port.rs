use crate::farm::dtos::FarmDestroyOutput;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait FarmDestroyOutputPort {
    fn on_success(&mut self, output: FarmDestroyOutput);
    fn on_failure(&mut self, error: DestroyFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum DestroyFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
