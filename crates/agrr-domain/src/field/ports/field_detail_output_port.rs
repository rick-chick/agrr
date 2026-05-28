use crate::field::dtos::FieldDetailFailure;
use crate::field::results::FieldWithFarm;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

/// Ruby: `Domain::Field::Ports::FieldDetailOutputPort`
pub trait FieldDetailOutputPort {
    fn on_success(&mut self, result: FieldWithFarm);
    fn on_failure(&mut self, error: DetailFailure);
}

#[derive(Debug, Clone, PartialEq)]
pub enum DetailFailure {
    Policy(PolicyPermissionDenied),
    FieldDetail(FieldDetailFailure),
}
