use crate::crop::dtos::CropDestroyOutput;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

#[derive(Debug)]
pub enum DestroyFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}

pub trait CropDestroyOutputPort {
    fn on_success(&mut self, output: CropDestroyOutput);
    fn on_failure(&mut self, error: DestroyFailure);
}
