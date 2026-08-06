//! Personal organization backfill at startup (issue #611).

use agrr_adapters_sqlite::organization::PersonalOrganizationSqliteGateway;
use agrr_domain::organization::interactors::PersonalOrganizationBackfillInteractor;

use crate::state::AppState;

/// Ensures every user has a 1:1 personal org and Tier 1 `organization_id` backfill.
pub fn run_personal_organization_backfill(state: &AppState) {
    let gateway = PersonalOrganizationSqliteGateway::new(state.sqlite.clone());
    let interactor = PersonalOrganizationBackfillInteractor::new(&gateway);
    match interactor.call() {
        Ok(processed) => {
            if processed > 0 {
                tracing::info!(processed, "personal organization backfill completed");
            }
        }
        Err(error) => {
            tracing::warn!(error = %error, "personal organization backfill failed");
        }
    }
}
