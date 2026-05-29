//! Ruby: `Adapters::ApiKeys::Gateways::UserApiKeyRotationActiveRecordGateway`

use crate::pool::SqlitePool;
use agrr_domain::api_keys::dtos::{UserApiKeyRotationError, UserApiKeyRotationOutput};
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
                    "SELECT api_key FROM users WHERE id = ?1",
                    params![user_id],
                    |row| row.get(0),
                )
            })
            .ok()
            .flatten();
        if !regenerate && existing.as_ref().is_some_and(|k| !k.is_empty()) {
            return UserApiKeyRotationOutput::new(true, existing, None);
        }
        for _ in 0..10 {
            let key = Self::random_key();
            let updated = self
                .pool
                .with_write(|conn| {
                    conn.execute(
                        "UPDATE users SET api_key = ?1, updated_at = datetime('now') WHERE id = ?2",
                        params![key, user_id],
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
