//! Ruby: `Adapters::Shared::Gateways::ApiKeyPrincipalActiveRecordGateway`

use crate::pool::SqlitePool;
use agrr_domain::shared::dtos::SessionPrincipal;
use agrr_domain::shared::gateways::ApiKeyPrincipalGateway;
use rusqlite::{params, OptionalExtension};

pub struct ApiKeyPrincipalSqliteGateway {
    pool: SqlitePool,
}

impl ApiKeyPrincipalSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl ApiKeyPrincipalGateway for ApiKeyPrincipalSqliteGateway {
    fn principal_for_api_key(&self, api_key: &str) -> Option<SessionPrincipal> {
        self.pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT id, COALESCE(email, ''), COALESCE(name, ''), \
                     COALESCE(admin, 0), COALESCE(is_anonymous, 0) \
                     FROM users WHERE api_key = ?1 LIMIT 1",
                    params![api_key],
                    |row| {
                        Ok(SessionPrincipal {
                            id: row.get(0)?,
                            email: row.get(1)?,
                            name: row.get(2)?,
                            admin: row.get::<_, i64>(3)? != 0,
                            anonymous: row.get::<_, i64>(4)? != 0,
                        })
                    },
                )
                .optional()
            })
            .ok()
            .flatten()
    }
}
