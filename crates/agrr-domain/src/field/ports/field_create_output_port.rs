use crate::field::entities::FieldEntity;
use crate::shared::dtos::error::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::Field::Ports::FieldCreateOutputPort`
pub trait FieldCreateOutputPort {
    fn on_success(&mut self, field: FieldEntity);
    fn on_failure(&mut self, error: CreateFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum CreateFailure {
    Policy(PolicyPermissionDenied),
    Error(Error),
}
