//! Resolves organization IDs a user may access via membership (ADR-002 §4).

/// Narrow port for org-scoped authorization without pulling full membership CRUD.
pub trait UserOrganizationScopeGateway: Send + Sync {
    fn organization_ids_for_user(
        &self,
        user_id: i64,
    ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>>;
}
