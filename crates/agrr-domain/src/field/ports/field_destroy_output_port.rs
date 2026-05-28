use crate::field::dtos::FieldDestroyOutput;
use crate::shared::dtos::error::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::Field::Ports::FieldDestroyOutputPort`
pub trait FieldDestroyOutputPort {
    fn on_success(&mut self, dto: FieldDestroyOutput);
    fn on_failure(&mut self, error: DestroyFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum DestroyFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
