use crate::fertilize::dtos::FertilizeDetailOutput;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait FertilizeDetailOutputPort {
    fn on_success(&mut self, dto: FertilizeDetailOutput);
    fn on_failure(&mut self, error: DetailFailure);
}

#[derive(Debug, Clone)]
pub enum DetailFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
