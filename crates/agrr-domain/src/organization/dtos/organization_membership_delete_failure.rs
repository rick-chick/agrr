use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum OrganizationMembershipDeleteFailure {
    LastOwnerForbidden,
    Policy(PolicyPermissionDenied),
    NotFound,
    Error(Error),
}
