use crate::pest::dtos::PestDetailOutput;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait PestDetailOutputPort {
    fn on_success(&mut self, output: PestDetailOutput);
    fn on_failure(&mut self, error: DetailFailure);
}

#[derive(Debug, Clone)]
pub enum DetailFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
