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

/// Actor may manage a membership row with `target_role` (remove or role change).
/// `owner` memberships require an `owner` actor; `admin` cannot touch `owner` rows.
pub fn manage_target_member_allowed(
    actor_role: OrganizationRole,
    target_role: OrganizationRole,
) -> bool {
    if target_role == OrganizationRole::Owner {
        return actor_role == OrganizationRole::Owner;
    }
    manage_members_allowed(actor_role)
}

/// Actor may create a membership with `new_role`.
pub fn create_membership_allowed(actor_role: OrganizationRole, new_role: OrganizationRole) -> bool {
    if !manage_members_allowed(actor_role) {
        return false;
    }
    if new_role == OrganizationRole::Owner {
        return actor_role == OrganizationRole::Owner;
    }
    true
}

/// Actor may change `target_current_role` to `new_role`.
pub fn update_member_role_allowed(
    actor_role: OrganizationRole,
    target_current_role: OrganizationRole,
    new_role: OrganizationRole,
) -> bool {
    if !manage_target_member_allowed(actor_role, target_current_role) {
        return false;
    }
    if new_role == OrganizationRole::Owner && actor_role != OrganizationRole::Owner {
        return false;
    }
    true
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
