use crate::organization::dtos::OrganizationRole;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OrganizationMembershipCreateInput {
    pub user_id: i64,
    pub role: OrganizationRole,
}
