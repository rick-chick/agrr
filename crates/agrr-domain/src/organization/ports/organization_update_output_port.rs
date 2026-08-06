use crate::organization::entities::OrganizationEntity;
use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum UpdateFailure {
    Policy(PolicyPermissionDenied),
    NotFound,
    Error(Error),
}

pub trait OrganizationUpdateOutputPort {
    fn on_success(&mut self, organization: OrganizationEntity);
    fn on_failure(&mut self, failure: UpdateFailure);
}
