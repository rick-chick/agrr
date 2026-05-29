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
        let admin = self
            .pool
            .with_read(|conn| {
                let admin: i64 = conn.query_row(
                    "SELECT COALESCE(admin, 0) FROM users WHERE id = ?1",
                    params![user_id],
                    |row| row.get(0),
                )?;
                Ok(admin != 0)
            })
            .unwrap_or(false);
        User::new(user_id, admin)
    }
}
