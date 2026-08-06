//! Ruby: `Domain::Organization::Policies::OrganizationAccessPolicy`
//!
//! Membership + role + `organization_id` match (ADR-002 §4).

use crate::organization::dtos::OrganizationRole;
use crate::organization::entities::OrganizationMembershipEntity;
use crate::shared::user::User;

/// System admin bypasses org membership checks.
pub fn system_admin_access(user: &User) -> bool {
    user.admin
}

/// Actor may access the organization (view org metadata).
pub fn member_access_allowed(
    user: &User,
    membership: Option<&OrganizationMembershipEntity>,
    organization_id: i64,
) -> bool {
    if user.admin {
        return true;
    }
    membership.is_some_and(|m| {
        m.organization_id == organization_id && m.user_id == user.id
    })
}

/// Actor may access a resource scoped to `resource_organization_id`.
pub fn resource_access_allowed(
    user: &User,
    membership: Option<&OrganizationMembershipEntity>,
    resource_organization_id: i64,
) -> bool {
    member_access_allowed(user, membership, resource_organization_id)
}

/// `owner` / `admin` may manage memberships.
pub fn manage_members_allowed(role: OrganizationRole) -> bool {
    matches!(role, OrganizationRole::Owner | OrganizationRole::Admin)
}

/// Only `owner` may update org settings; `member` is read-only for org metadata.
pub fn update_organization_allowed(role: OrganizationRole) -> bool {
    matches!(role, OrganizationRole::Owner | OrganizationRole::Admin)
}

/// Personal orgs cannot be deleted; only `owner` may delete team orgs.
pub fn delete_organization_allowed(role: OrganizationRole, is_personal: bool) -> bool {
    !is_personal && role == OrganizationRole::Owner
}

#[cfg(test)]
mod policies_organization_access_policy_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/organization/policies_organization_access_policy_test.rs"
    ));
}
