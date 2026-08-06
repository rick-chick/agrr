use crate::organization::dtos::OrganizationRole;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OrganizationMembershipUpdateInput {
    pub role: OrganizationRole,
}
