//! Ruby: `Domain::Organization::Entities::OrganizationMembershipEntity`

use crate::organization::dtos::OrganizationRole;

/// Links a user to an organization with a role.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OrganizationMembershipEntity {
    pub id: i64,
    pub organization_id: i64,
    pub user_id: i64,
    pub role: OrganizationRole,
    pub created_at: String,
    pub updated_at: String,
}

#[cfg(test)]
mod entities_organization_membership_entity_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/organization/entities_organization_membership_entity_test.rs"
    ));
}
