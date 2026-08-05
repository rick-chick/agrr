//! Ruby: `Adapters::ApiKeys::Gateways::UserApiKeyRotationActiveRecordGateway`

use crate::pool::SqlitePool;
use agrr_domain::api_keys::dtos::{UserApiKeyRotationError, UserApiKeyRotationOutput};
use agrr_domain::api_keys::gateways::UserApiKeyRotationGateway;
use agrr_domain::shared::policies::masters_api_scope_policy::{
    normalize_requested_api_key_scopes, parse_api_key_scopes_json, serialize_api_key_scopes,
};
use getrandom::getrandom;
use rusqlite::params;

pub struct UserApiKeyRotationSqliteGateway {
    pool: SqlitePool,
}

impl UserApiKeyRotationSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn random_key() -> String {
        let mut bytes = [0u8; 32];
        getrandom(&mut bytes).expect("random");
        bytes.iter().map(|b| format!("{b:02x}")).collect()
    }

    fn read_existing_scopes(&self, user_id: i64) -> Option<Vec<String>> {
        let scopes_raw: Option<String> = self
            .pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT api_key_scopes FROM users WHERE id = ?1",
                    params![user_id],
                    |row| row.get(0),
                )
            })
            .ok()
            .flatten();
        scopes_raw
            .as_deref()
            .and_then(|raw| parse_api_key_scopes_json(Some(raw)))
    }
}

impl UserApiKeyRotationGateway for UserApiKeyRotationSqliteGateway {
    fn rotate(
        &self,
        user_id: i64,
        regenerate: bool,
        scopes: Option<Vec<String>>,
    ) -> UserApiKeyRotationOutput {
        let existing: Option<String> = self
            .pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT api_key FROM users WHERE id = ?1",
                    params![user_id],
                    |row| row.get(0),
                )
            })
            .ok()
            .flatten();
        if !regenerate && existing.as_ref().is_some_and(|k| !k.is_empty()) {
            let scopes = self
                .read_existing_scopes(user_id)
                .unwrap_or_else(|| normalize_requested_api_key_scopes(None));
            return UserApiKeyRotationOutput::new(true, existing, Some(scopes), None);
        }

        let scopes = normalize_requested_api_key_scopes(scopes);
        let scopes_json = serialize_api_key_scopes(&scopes);

        for _ in 0..10 {
            let key = Self::random_key();
            let updated = self
                .pool
                .with_write(|conn| {
                    conn.execute(
                        "UPDATE users SET api_key = ?1, api_key_scopes = ?2, updated_at = datetime('now') WHERE id = ?3",
                        params![key, scopes_json, user_id],
                    )
                })
                .unwrap_or(0);
            if updated > 0 {
                return UserApiKeyRotationOutput::new(true, Some(key), Some(scopes), None);
            }
        }
        UserApiKeyRotationOutput::new(
            false,
            None,
            None,
            Some(UserApiKeyRotationError::NotFound),
        )
    }
}
