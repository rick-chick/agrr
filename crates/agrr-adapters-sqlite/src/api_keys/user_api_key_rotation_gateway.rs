//! Ruby: `Adapters::ApiKeys::Gateways::UserApiKeyRotationActiveRecordGateway`

use super::api_key_storage::{api_key_prefix, hash_api_key};
use crate::pool::SqlitePool;
use agrr_domain::api_keys::dtos::{UserApiKeyRotationError, UserApiKeyRotationOutput};
use agrr_domain::shared::dtos::default_api_key_scopes_json;
use agrr_domain::api_keys::gateways::UserApiKeyRotationGateway;
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
}

impl UserApiKeyRotationGateway for UserApiKeyRotationSqliteGateway {
    fn rotate(&self, user_id: i64, regenerate: bool) -> UserApiKeyRotationOutput {
        let existing: Option<String> = self
            .pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT api_key_hash FROM users WHERE id = ?1",
                    params![user_id],
                    |row| row.get(0),
                )
            })
            .ok()
            .flatten();
        if !regenerate && existing.as_ref().is_some_and(|k| !k.is_empty()) {
            return UserApiKeyRotationOutput::new(true, None, None);
        }
        let default_scopes = default_api_key_scopes_json();
        for _ in 0..10 {
            let key = Self::random_key();
            let key_hash = hash_api_key(&key);
            let prefix = api_key_prefix(&key);
            let updated = self
                .pool
                .with_write(|conn| {
                    conn.execute(
                        "UPDATE users SET api_key = NULL, api_key_hash = ?1, api_key_prefix = ?2, \
                         api_key_scopes = ?3, updated_at = datetime('now') WHERE id = ?4",
                        params![key_hash, prefix, default_scopes, user_id],
                    )
                })
                .unwrap_or(0);
            if updated > 0 {
                return UserApiKeyRotationOutput::new(true, Some(key), None);
            }
        }
        UserApiKeyRotationOutput::new(
            false,
            None,
            Some(UserApiKeyRotationError::NotFound),
        )
    }
}
