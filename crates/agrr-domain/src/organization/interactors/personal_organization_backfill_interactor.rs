//! Backfill personal organizations for all users missing one.

use crate::organization::gateways::PersonalOrganizationGateway;

/// Ensures every user has a personal organization and Tier 1 `organization_id` backfill.
pub struct PersonalOrganizationBackfillInteractor<'a> {
    gateway: &'a dyn PersonalOrganizationGateway,
}

impl<'a> PersonalOrganizationBackfillInteractor<'a> {
    pub fn new(gateway: &'a dyn PersonalOrganizationGateway) -> Self {
        Self { gateway }
    }

    /// Returns the number of users that were processed (including already-complete re-runs).
    pub fn call(&self) -> Result<usize, Box<dyn std::error::Error + Send + Sync>> {
        let users = self.gateway.list_users_needing_personal_organization()?;
        let mut processed = 0usize;
        for row in users {
            self.gateway
                .ensure_personal_organization(row.user_id, &row.email, &row.name)?;
            processed += 1;
        }
        Ok(processed)
    }
}

#[cfg(test)]
mod interactors_personal_organization_backfill_interactor_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/organization/interactors_personal_organization_backfill_interactor_test.rs"
    ));
}
