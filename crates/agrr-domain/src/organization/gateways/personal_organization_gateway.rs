//! Backfill and ensure 1:1 personal organizations for users.

/// User row needed to create or backfill a personal organization.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PersonalOrganizationUserRow {
    pub user_id: i64,
    pub email: String,
    pub name: String,
}

/// Ruby: `Domain::Organization::Gateways::PersonalOrganizationGateway`
pub trait PersonalOrganizationGateway: Send + Sync {
    /// Ensures the user has a personal org (owner membership) and Tier 1 `organization_id` backfill.
    /// Idempotent — safe to call repeatedly.
    fn ensure_personal_organization(
        &self,
        user_id: i64,
        email: &str,
        name: &str,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>>;

    /// Users without an `is_personal = 1` organization membership.
    fn list_users_needing_personal_organization(
        &self,
    ) -> Result<Vec<PersonalOrganizationUserRow>, Box<dyn std::error::Error + Send + Sync>>;
}
