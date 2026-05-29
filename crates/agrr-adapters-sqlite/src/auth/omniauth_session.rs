use crate::auth::session_lookup::SessionLookupSqliteGateway;
use crate::pool::SqlitePool;
use rusqlite::params;

#[derive(Debug, Clone)]
pub struct GoogleOAuthUserInfo {
    pub google_id: String,
    pub email: String,
    pub name: String,
    pub avatar_url: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum OmniauthCallbackStatus {
    Success,
    UserNotPersisted,
    RecordInvalid,
    InfrastructureError,
}

#[derive(Debug, Clone)]
pub struct OmniauthCallbackResult {
    pub status: OmniauthCallbackStatus,
    pub user_id: Option<i64>,
    pub session_id: Option<String>,
    pub expires_at_rfc3339: Option<String>,
}

pub struct AuthOmniauthSessionSqliteGateway {
    pool: SqlitePool,
}

impl AuthOmniauthSessionSqliteGateway {
    pub fn new(pool: SqlitePool) -> Self {
        Self { pool }
    }

    /// Ruby: `AuthOmniauthSessionActiveRecordGateway#process_google_callback`
    pub fn process_google_callback(
        &self,
        info: &GoogleOAuthUserInfo,
    ) -> OmniauthCallbackResult {
        if info.google_id.is_empty() || info.email.is_empty() || info.name.is_empty() {
            return OmniauthCallbackResult {
                status: OmniauthCallbackStatus::RecordInvalid,
                user_id: None,
                session_id: None,
                expires_at_rfc3339: None,
            };
        }

        let user_id = match self.upsert_user(info) {
            Ok(id) => id,
            Err(_) => {
                return OmniauthCallbackResult {
                    status: OmniauthCallbackStatus::InfrastructureError,
                    user_id: None,
                    session_id: None,
                    expires_at_rfc3339: None,
                };
            }
        };

        let sessions = SessionLookupSqliteGateway::new(self.pool.clone());
        match sessions.create_for_user(user_id) {
            Ok(record) => {
                OmniauthCallbackResult {
                    status: OmniauthCallbackStatus::Success,
                    user_id: Some(user_id),
                    session_id: Some(record.session_id),
                    expires_at_rfc3339: Some(record.expires_at),
                }
            }
            Err(_) => OmniauthCallbackResult {
                status: OmniauthCallbackStatus::UserNotPersisted,
                user_id: Some(user_id),
                session_id: None,
                expires_at_rfc3339: None,
            },
        }
    }

    fn upsert_user(&self, info: &GoogleOAuthUserInfo) -> rusqlite::Result<i64> {
        let avatar = info.avatar_url.as_deref().map(process_avatar_url);
        self.pool.with_write(|conn| {
            let existing: Option<i64> = conn
                .query_row(
                    "SELECT id FROM users WHERE google_id = ?1 AND (is_anonymous = 0 OR is_anonymous IS NULL)",
                    params![info.google_id],
                    |row| row.get(0),
                )
                .ok();
            if let Some(id) = existing {
                conn.execute(
                    "UPDATE users SET email = ?1, name = ?2, avatar_url = ?3, updated_at = datetime('now') WHERE id = ?4",
                    params![info.email.to_lowercase(), info.name, avatar, id],
                )?;
                return Ok(id);
            }
            conn.execute(
                "INSERT INTO users (email, name, google_id, avatar_url, is_anonymous, admin, created_at, updated_at) \
                 VALUES (?1, ?2, ?3, ?4, 0, 0, datetime('now'), datetime('now'))",
                params![info.email.to_lowercase(), info.name, info.google_id, avatar],
            )?;
            Ok(conn.last_insert_rowid())
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::auth::session_lookup::SessionLookupSqliteGateway;
    use crate::pool::SqlitePool;

    fn temp_pool() -> SqlitePool {
        let dir = std::env::temp_dir().join(format!("agrr_auth_test_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("auth.sqlite3");
        let pool = SqlitePool::new(path.to_str().unwrap());
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE users (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  email TEXT, name TEXT, google_id TEXT,
                  avatar_url TEXT, is_anonymous INTEGER DEFAULT 0,
                  admin INTEGER DEFAULT 0,
                  created_at TEXT, updated_at TEXT
                );
                CREATE TABLE sessions (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  session_id TEXT NOT NULL UNIQUE,
                  user_id INTEGER NOT NULL,
                  expires_at TEXT NOT NULL,
                  created_at TEXT, updated_at TEXT
                );",
            )?;
            Ok(())
        })
        .unwrap();
        pool
    }

    #[test]
    fn process_google_callback_creates_session() {
        let pool = temp_pool();
        let gateway = AuthOmniauthSessionSqliteGateway::new(pool.clone());
        let result = gateway.process_google_callback(&GoogleOAuthUserInfo {
            google_id: "gid".into(),
            email: "a@example.com".into(),
            name: "Test".into(),
            avatar_url: None,
        });
        assert_eq!(result.status, OmniauthCallbackStatus::Success);
        let sid = result.session_id.expect("session_id");
        let lookup = SessionLookupSqliteGateway::new(pool);
        assert!(lookup.find_active_by_session_id(&sid).unwrap().is_some());
    }
}

fn process_avatar_url(url: &str) -> Option<String> {
    if url.is_empty() {
        return None;
    }
    if let Some(rest) = url.strip_prefix("/assets/") {
        Some(rest.to_string())
    } else {
        Some(url.to_string())
    }
}
