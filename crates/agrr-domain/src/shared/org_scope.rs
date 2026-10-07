//! Helpers for resolving org membership scope in interactors.

use crate::organization::gateways::PersonalOrganizationGateway;
use crate::shared::gateways::UserOrganizationScopeGateway;

/// Organization used when creating Farm / Crop / plan-save copies (Masters parity).
///
/// First membership id when present; otherwise ensures a personal organization.
pub fn resolve_creation_organization_id<G, P>(
    scope_gateway: &G,
    personal_org_gateway: &P,
    user_id: i64,
) -> Result<i64, Box<dyn std::error::Error + Send + Sync>>
where
    G: UserOrganizationScopeGateway,
    P: PersonalOrganizationGateway,
{
    let org_ids = member_organization_ids(scope_gateway, user_id)?;
    if let Some(&id) = org_ids.first() {
        Ok(id)
    } else {
        personal_org_gateway.ensure_personal_organization(user_id, "", "")
    }
}

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
