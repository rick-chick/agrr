use crate::pool::SqlitePool;
use agrr_domain::shared::gateways::UserLookupGateway;
use agrr_domain::shared::user::User;
use rusqlite::params;

pub struct UserLookupSqliteGateway {
    pool: SqlitePool,
}

impl UserLookupSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl UserLookupGateway for UserLookupSqliteGateway {
    fn find(&self, user_id: i64) -> User {
        self.pool
            .with_read(|conn| {
                conn.query_row(
                    "SELECT COALESCE(admin, 0), COALESCE(is_anonymous, 0) FROM users WHERE id = ?1",
                    params![user_id],
                    |row| {
                        Ok(User {
                            id: user_id,
                            admin: row.get::<_, i64>(0)? != 0,
                            anonymous: row.get::<_, i64>(1)? != 0,
                        })
                    },
                )
            })
            .unwrap_or_else(|_| User {
                id: user_id,
                admin: false,
                anonymous: false,
            })
    }
}
