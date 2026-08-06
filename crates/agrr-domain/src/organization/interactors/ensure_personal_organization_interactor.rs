//! Ensures a single user has a personal organization and Tier 1 backfill.

use crate::organization::gateways::PersonalOrganizationGateway;

/// Idempotently creates personal org + membership and backfills Tier 1 `organization_id`.
pub struct EnsurePersonalOrganizationInteractor<'a> {
    gateway: &'a dyn PersonalOrganizationGateway,
}

impl<'a> EnsurePersonalOrganizationInteractor<'a> {
    pub fn new(gateway: &'a dyn PersonalOrganizationGateway) -> Self {
        Self { gateway }
    }

    /// Returns the personal `organization_id`.
    pub fn call(
        &self,
        user_id: i64,
        email: &str,
        name: &str,
    ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
        self.gateway
            .ensure_personal_organization(user_id, email, name)
    }
}

#[cfg(test)]
mod interactors_ensure_personal_organization_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/organization/interactors_ensure_personal_organization_interactor_test.rs"
    ));
}
