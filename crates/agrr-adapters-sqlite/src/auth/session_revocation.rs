use crate::pool::SqlitePool;
use agrr_domain::auth::gateways::UserSessionRevocationGateway;

pub struct UserSessionRevocationSqliteGateway {
    pool: SqlitePool,
}

impl UserSessionRevocationSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }
}

impl UserSessionRevocationGateway for UserSessionRevocationSqliteGateway {
    fn delete_session_by_session_id(&self, session_id: &str) {
        let _ = self.pool.with_write(|conn| {
            conn.execute("DELETE FROM sessions WHERE session_id = ?1", [session_id])?;
            Ok(())
        });
    }

    fn delete_all_sessions_for_user(&self, user_id: i64) {
        let _ = self.pool.with_write(|conn| {
            conn.execute("DELETE FROM sessions WHERE user_id = ?1", [user_id])?;
            Ok(())
        });
    }
}
