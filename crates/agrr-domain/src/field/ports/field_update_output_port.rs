use crate::field::entities::FieldEntity;
use crate::shared::dtos::error::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::Field::Ports::FieldUpdateOutputPort`
pub trait FieldUpdateOutputPort {
    fn on_success(&mut self, field: FieldEntity);
    fn on_failure(&mut self, error: UpdateFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum UpdateFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
