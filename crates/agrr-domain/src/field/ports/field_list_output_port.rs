use crate::field::results::FarmFieldsList;
use crate::shared::dtos::error::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::Field::Ports::FieldListOutputPort`
pub trait FieldListOutputPort {
    fn on_success(&mut self, result: FarmFieldsList);
    fn on_failure(&mut self, error: ListFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum ListFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
