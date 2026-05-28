use crate::agricultural_task::dtos::AgriculturalTaskDetailOutput;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait AgriculturalTaskDetailOutputPort {
    fn on_success(&mut self, dto: AgriculturalTaskDetailOutput);
    fn on_failure(&mut self, error: DetailFailure);
}

#[derive(Debug, Clone)]
pub enum DetailFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
