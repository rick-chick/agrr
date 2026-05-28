use crate::agricultural_task::dtos::AgriculturalTaskDestroyOutput;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub trait AgriculturalTaskDestroyOutputPort {
    fn on_success(&mut self, dto: AgriculturalTaskDestroyOutput);
    fn on_failure(&mut self, error: DestroyFailure);
}

#[derive(Debug, Clone)]
pub enum DestroyFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
