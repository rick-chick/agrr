//! Helpers for resolving org membership scope in interactors.

use crate::shared::gateways::UserOrganizationScopeGateway;

/// Organization IDs the actor may access (all memberships).
pub fn member_organization_ids<G: UserOrganizationScopeGateway>(
    gateway: &G,
    user_id: i64,
) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
    gateway.organization_ids_for_user(user_id)
}

/// Whether `organization_id` is in the actor's membership scope.
pub fn organization_member_access(
    member_organization_ids: &[i64],
    is_reference: bool,
    record_organization_id: Option<i64>,
) -> bool {
    if is_reference {
        return false;
    }
    record_organization_id.is_some_and(|id| member_organization_ids.contains(&id))
}
