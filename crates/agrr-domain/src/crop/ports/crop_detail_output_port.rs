use crate::crop::dtos::CropDetailOutput;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

pub enum DetailFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}

pub trait CropDetailOutputPort {
    fn on_success(&mut self, output: CropDetailOutput);
    fn on_failure(&mut self, error: DetailFailure);
}
