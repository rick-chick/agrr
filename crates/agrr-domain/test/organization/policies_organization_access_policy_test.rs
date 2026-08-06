// Tests for `policies/organization_access_policy.rs`

use crate::organization::dtos::OrganizationRole;
use crate::organization::entities::OrganizationMembershipEntity;
use crate::organization::policies::{
    delete_organization_allowed, manage_members_allowed, member_access_allowed,
    resource_access_allowed, system_admin_access, update_organization_allowed,
};
use crate::shared::user::User;

fn membership(org_id: i64, user_id: i64, role: OrganizationRole) -> OrganizationMembershipEntity {
    OrganizationMembershipEntity {
        id: 1,
        organization_id: org_id,
        user_id,
        role,
        created_at: String::new(),
        updated_at: String::new(),
    }
}

#[test]
fn system_admin_access_true_for_admin() {
    assert!(system_admin_access(&User::new(1, true)));
    assert!(!system_admin_access(&User::new(1, false)));
}

#[test]
fn admin_bypasses_membership_check() {
    let admin = User::new(1, true);
    assert!(member_access_allowed(&admin, None, 99));
    assert!(resource_access_allowed(&admin, None, 99));
}

#[test]
fn member_access_requires_matching_org_and_user() {
    let user = User::new(5, false);
    let m = membership(10, 5, OrganizationRole::Member);
    assert!(member_access_allowed(&user, Some(&m), 10));
    assert!(!member_access_allowed(&user, Some(&m), 11));
    assert!(!member_access_allowed(&user, None, 10));
}

#[test]
fn manage_members_allowed_for_owner_and_admin_only() {
    assert!(manage_members_allowed(OrganizationRole::Owner));
    assert!(manage_members_allowed(OrganizationRole::Admin));
    assert!(!manage_members_allowed(OrganizationRole::Member));
}

#[test]
fn update_organization_allowed_for_owner_and_admin_only() {
    assert!(update_organization_allowed(OrganizationRole::Owner));
    assert!(update_organization_allowed(OrganizationRole::Admin));
    assert!(!update_organization_allowed(OrganizationRole::Member));
}

#[test]
fn delete_organization_allowed_for_owner_of_non_personal_only() {
    assert!(delete_organization_allowed(OrganizationRole::Owner, false));
    assert!(!delete_organization_allowed(OrganizationRole::Owner, true));
    assert!(!delete_organization_allowed(OrganizationRole::Admin, false));
    assert!(!delete_organization_allowed(OrganizationRole::Member, false));
}
