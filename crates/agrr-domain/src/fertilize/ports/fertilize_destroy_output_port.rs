use crate::fertilize::dtos::FertilizeDestroyOutput;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait FertilizeDestroyOutputPort {
    fn on_success(&mut self, dto: FertilizeDestroyOutput);
    fn on_failure(&mut self, error: DestroyFailure);
}

#[derive(Debug, Clone)]
pub enum DestroyFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
