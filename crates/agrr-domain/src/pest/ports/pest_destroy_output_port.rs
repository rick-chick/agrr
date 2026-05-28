use crate::pest::dtos::PestDestroyOutput;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait PestDestroyOutputPort {
    fn on_success(&mut self, output: PestDestroyOutput);
    fn on_failure(&mut self, error: DestroyFailure);
}

#[derive(Debug, Clone)]
pub enum DestroyFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
