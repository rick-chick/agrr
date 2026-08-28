//! Startup backfill for legacy plaintext API keys (issue #1204).

use agrr_adapters_sqlite::backfill_plaintext_api_keys;

use crate::state::AppState;

/// Migrates any remaining plaintext `users.api_key` rows to hashed storage.
pub fn run_api_key_hash_backfill(state: &AppState) {
    match backfill_plaintext_api_keys(&state.sqlite) {
        Ok(migrated) => {
            if migrated > 0 {
                tracing::info!(migrated, "api key hash backfill completed");
            }
        }
        Err(error) => {
            tracing::warn!(error = %error, "api key hash backfill failed");
        }
    }
}
