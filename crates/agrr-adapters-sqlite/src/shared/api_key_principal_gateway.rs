//! Ruby: `Adapters::Shared::Gateways::ApiKeyPrincipalActiveRecordGateway`

use crate::api_keys::{api_key_prefix, hash_api_key, verify_api_key_hash};
use crate::pool::SqlitePool;
use agrr_domain::shared::dtos::{parse_api_key_scopes_json, SessionPrincipal};
use agrr_domain::shared::gateways::ApiKeyPrincipalGateway;
use rusqlite::{params, OptionalExtension};

pub struct ApiKeyPrincipalSqliteGateway {
    pool: SqlitePool,
}

impl ApiKeyPrincipalSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn row_to_principal(
        row: &rusqlite::Row<'_>,
    ) -> rusqlite::Result<SessionPrincipal> {
        let scopes_raw: Option<String> = row.get(5)?;
        Ok(SessionPrincipal {
            id: row.get(0)?,
            email: row.get(1)?,
            name: row.get(2)?,
            admin: row.get::<_, i64>(3)? != 0,
            anonymous: row.get::<_, i64>(4)? != 0,
            api_key_scopes: Some(parse_api_key_scopes_json(scopes_raw.as_deref())),
        })
    }

    fn migrate_legacy_plaintext(&self, user_id: i64, api_key: &str) {
        let key_hash = hash_api_key(api_key);
        let prefix = api_key_prefix(api_key);
        let _ = self.pool.with_write(|conn| {
            conn.execute(
                "UPDATE users SET api_key = NULL, api_key_hash = ?1, api_key_prefix = ?2, \
                 updated_at = datetime('now') WHERE id = ?3",
                params![key_hash, prefix, user_id],
            )
        });
    }
}

impl ApiKeyPrincipalGateway for ApiKeyPrincipalSqliteGateway {
    fn principal_for_api_key(&self, api_key: &str) -> Option<SessionPrincipal> {
        let prefix = api_key_prefix(api_key);

        if let Ok(principal) = self.pool.with_read(|conn| {
                let mut stmt = conn.prepare(
                    "SELECT id, COALESCE(email, ''), COALESCE(name, ''), \
                     COALESCE(admin, 0), COALESCE(is_anonymous, 0), api_key_scopes, api_key_hash \
                     FROM users WHERE api_key_prefix = ?1 AND api_key_hash IS NOT NULL",
                )?;
                let mut rows = stmt.query(params![prefix])?;
                while let Some(row) = rows.next()? {
                    let stored_hash: String = row.get(6)?;
                    if verify_api_key_hash(api_key, &stored_hash) {
                        return Self::row_to_principal(row);
                    }
                }
                Err(rusqlite::Error::QueryReturnedNoRows)
            }) {
            return Some(principal);
        }

        let legacy_plaintext = self
            .pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT id, COALESCE(email, ''), COALESCE(name, ''), \
                     COALESCE(admin, 0), COALESCE(is_anonymous, 0), api_key_scopes, api_key \
                     FROM users WHERE api_key = ?1 LIMIT 1",
                    params![api_key],
                    |row| {
                        let stored_plain: Option<String> = row.get(6)?;
                        let stored_plain = stored_plain.filter(|k| !k.is_empty());
                        if stored_plain.as_deref() == Some(api_key) {
                            return Self::row_to_principal(row);
                        }
                        Err(rusqlite::Error::QueryReturnedNoRows)
                    },
                )
                .optional()
            })
            .ok()
            .flatten();

        if let Some(principal) = legacy_plaintext {
            self.migrate_legacy_plaintext(principal.id, api_key);
            return Some(principal);
        }

        None
    }
}
