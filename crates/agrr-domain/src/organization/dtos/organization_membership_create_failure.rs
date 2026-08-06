use crate::shared::dtos::Error;
use crate::shared::policies::policy_permission_denied::PolicyPermissionDenied;

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum OrganizationMembershipCreateFailure {
    AlreadyMember,
    Policy(PolicyPermissionDenied),
    NotFound,
    Error(Error),
}
