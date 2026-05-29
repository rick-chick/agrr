//! Ruby: `Adapters::Shared::Gateways::AuthTestLoginActiveRecordGateway`

use crate::auth::session_lookup::SessionLookupSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::auth::dtos::{
    AuthTestMockLoginInput, AuthTestMockLoginPersistResult,
};
use agrr_domain::auth::gateways::AuthTestLoginGateway;
use rusqlite::params;

pub struct AuthTestLoginSqliteGateway {
    pool: SqlitePool,
}

impl AuthTestLoginSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl AuthTestLoginGateway for AuthTestLoginSqliteGateway {
    fn persist_mock_user_and_session(
        &self,
        input_dto: &AuthTestMockLoginInput,
    ) -> AuthTestMockLoginPersistResult {
        if input_dto.google_id.is_empty() || input_dto.email.is_empty() || input_dto.name.is_empty() {
            return AuthTestMockLoginPersistResult::record_invalid(vec![
                "google_id, email, and name are required".into(),
            ]);
        }
        let avatar = if input_dto.avatar_source_url.is_empty() {
            None
        } else {
            Some(input_dto.avatar_source_url.clone())
        };
        let user_id = match self.upsert_user(input_dto, &avatar) {
            Ok(id) => id,
            Err(_) => {
                return AuthTestMockLoginPersistResult::user_not_persisted(vec![
                    "database error".into(),
                ]);
            }
        };
        if input_dto.grant_admin {
            let _ = self.pool.with_write(|conn| {
                conn.execute(
                    "UPDATE users SET admin = 1, updated_at = datetime('now') WHERE id = ?1",
                    params![user_id],
                )
            });
        }
        let sessions = SessionLookupSqliteGateway::new(self.pool.clone());
        match sessions.create_for_user(user_id) {
            Ok(record) => {
                let expires = time::OffsetDateTime::parse(
                    &record.expires_at,
                    &time::format_description::well_known::Iso8601::DEFAULT,
                )
                .unwrap_or_else(|_| time::OffsetDateTime::now_utc() + time::Duration::weeks(2));
                AuthTestMockLoginPersistResult::success(
                    input_dto.name.clone(),
                    record.session_id,
                    expires,
                )
            }
            Err(_) => AuthTestMockLoginPersistResult::user_not_persisted(vec![
                "session create failed".into(),
            ]),
        }
    }
}

impl AuthTestLoginSqliteGateway {
    fn upsert_user(
        &self,
        input: &AuthTestMockLoginInput,
        avatar: &Option<String>,
    ) -> rusqlite::Result<i64> {
        self.pool.with_write(|conn| {
            let existing: Option<i64> = conn
                .query_row(
                    "SELECT id FROM users WHERE google_id = ?1",
                    params![input.google_id],
                    |row| row.get(0),
                )
                .ok();
            if let Some(id) = existing {
                conn.execute(
                    "UPDATE users SET email = ?1, name = ?2, avatar_url = ?3, updated_at = datetime('now') WHERE id = ?4",
                    params![input.email.to_lowercase(), input.name, avatar, id],
                )?;
                return Ok(id);
            }
            conn.execute(
                "INSERT INTO users (google_id, email, name, avatar_url, admin, is_anonymous, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, ?5, 0, datetime('now'), datetime('now'))",
                params![
                    input.google_id,
                    input.email.to_lowercase(),
                    input.name,
                    avatar,
                    if input.grant_admin { 1 } else { 0 },
                ],
            )?;
            Ok(conn.last_insert_rowid())
        })
    }
}
