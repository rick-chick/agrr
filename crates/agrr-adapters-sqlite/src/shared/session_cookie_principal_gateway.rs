//! Ruby: `Adapters::Shared::Gateways::SessionCookiePrincipalActiveRecordGateway`

use crate::auth::SessionLookupSqliteGateway;
use crate::pool::SqlitePool;
use agrr_domain::shared::dtos::SessionPrincipal;
use agrr_domain::shared::gateways::SessionCookiePrincipalGateway;
use rusqlite::params;

pub struct SessionCookiePrincipalSqliteGateway {
    pool: SqlitePool,
}

impl SessionCookiePrincipalSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    fn principal_for_user_id(&self, user_id: i64) -> SessionPrincipal {
        self.pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT id, COALESCE(email, ''), COALESCE(name, ''), \
                     COALESCE(admin, 0), COALESCE(is_anonymous, 0) \
                     FROM users WHERE id = ?1 LIMIT 1",
                    params![user_id],
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
            })
            .unwrap_or_else(|_| anonymous_principal())
    }

    fn anonymous_principal(&self) -> SessionPrincipal {
        self.pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT id, COALESCE(email, ''), COALESCE(name, ''), \
                     COALESCE(admin, 0), COALESCE(is_anonymous, 0) \
                     FROM users WHERE is_anonymous = 1 ORDER BY id ASC LIMIT 1",
                    [],
                    |row| {
                        Ok(SessionPrincipal {
                            id: row.get(0)?,
                            email: row.get(1)?,
                            name: row.get(2)?,
                            admin: row.get::<_, i64>(3)? != 0,
                            anonymous: true,
                        })
                    },
                )
            })
            .unwrap_or_else(|_| SessionPrincipal {
                id: 0,
                email: String::new(),
                name: String::new(),
                admin: false,
                anonymous: true,
            })
    }
}

fn anonymous_principal() -> SessionPrincipal {
    SessionPrincipal {
        id: 0,
        email: String::new(),
        name: String::new(),
        admin: false,
        anonymous: true,
    }
}

impl SessionCookiePrincipalGateway for SessionCookiePrincipalSqliteGateway {
    fn principal_for_session_cookie(&self, session_id: Option<&str>) -> SessionPrincipal {
        let Some(session_id) = session_id.filter(|s| !s.is_empty()) else {
            return self.anonymous_principal();
        };
        let lookup = SessionLookupSqliteGateway::new(self.pool.clone());
        match lookup.find_active_by_session_id(session_id) {
            Ok(Some(record)) => self.principal_for_user_id(record.user_id),
            _ => self.anonymous_principal(),
        }
    }
}
