use crate::state::AppState;
use agrr_adapters_sqlite::SessionLookupSqliteGateway;
use axum::http::StatusCode;
use axum_extra::extract::cookie::CookieJar;

/// Session user when present; otherwise the anonymous user row (Rails `current_user` parity for unauthenticated API).
pub fn user_id_from_session_or_anonymous(
    state: &AppState,
    jar: &CookieJar,
) -> Result<i64, StatusCode> {
    if let Ok(id) = user_id_from_session(state, jar) {
        return Ok(id);
    }
    state
        .sqlite
        .with_read(|conn| {
            conn.query_row(
                "SELECT id FROM users WHERE is_anonymous = 1 ORDER BY id ASC LIMIT 1",
                [],
                |row| row.get(0),
            )
        })
        .map_err(|_| StatusCode::UNAUTHORIZED)
}

pub fn user_id_from_session(
    state: &AppState,
    jar: &CookieJar,
) -> Result<i64, StatusCode> {
    let session_id = jar
        .get("session_id")
        .map(|c| c.value().to_string())
        .ok_or(StatusCode::UNAUTHORIZED)?;
    let lookup = SessionLookupSqliteGateway::new(state.sqlite.clone());
    let record = lookup
        .find_active_by_session_id(&session_id)
        .map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?
        .ok_or(StatusCode::UNAUTHORIZED)?;
    Ok(record.user_id)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::test_app_state;
    use agrr_adapters_sqlite::{SessionLookupSqliteGateway, SqlitePool};
    use axum::http::StatusCode;
    use axum_extra::extract::cookie::{Cookie, CookieJar};

    fn session_test_pool() -> SqlitePool {
        let dir = std::env::temp_dir().join(format!("agrr_session_auth_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join(format!(
            "session_auth_{}_{}.sqlite3",
            std::process::id(),
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let pool = SqlitePool::new(path.to_str().unwrap());
        pool.with_write(|conn| {
            conn.execute_batch(
                "CREATE TABLE users (
                  id INTEGER PRIMARY KEY,
                  email TEXT,
                  is_anonymous INTEGER DEFAULT 0
                );
                CREATE TABLE sessions (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  session_id TEXT NOT NULL UNIQUE,
                  user_id INTEGER NOT NULL,
                  expires_at TEXT NOT NULL,
                  created_at TEXT,
                  updated_at TEXT
                );
                INSERT INTO users (id, email) VALUES (42, 'user@example.com');",
            )?;
            Ok(())
        })
        .unwrap();
        pool
    }

    #[test]
    fn user_id_from_session_returns_unauthorized_without_cookie() {
        let state = test_app_state(session_test_pool());
        let jar = CookieJar::new();
        assert_eq!(
            user_id_from_session(&state, &jar),
            Err(StatusCode::UNAUTHORIZED)
        );
    }

    #[test]
    fn user_id_from_session_returns_user_id_for_active_session() {
        let pool = session_test_pool();
        let lookup = SessionLookupSqliteGateway::new(pool.clone());
        let session = lookup.create_for_user(42).expect("session");
        let state = test_app_state(pool);
        let jar = CookieJar::new().add(Cookie::new("session_id", session.session_id));

        assert_eq!(user_id_from_session(&state, &jar), Ok(42));
    }

    #[test]
    fn user_id_from_session_returns_unauthorized_for_expired_session() {
        let pool = session_test_pool();
        let lookup = SessionLookupSqliteGateway::new(pool.clone());
        let session = lookup.create_for_user(42).expect("session");
        pool.with_write(|conn| {
            conn.execute(
                "UPDATE sessions SET expires_at = '2000-01-01T00:00:00Z' WHERE session_id = ?1",
                rusqlite::params![session.session_id],
            )?;
            Ok(())
        })
        .unwrap();
        let state = test_app_state(pool);
        let jar = CookieJar::new().add(Cookie::new("session_id", session.session_id));

        assert_eq!(
            user_id_from_session(&state, &jar),
            Err(StatusCode::UNAUTHORIZED)
        );
    }

    #[test]
    fn user_id_from_session_returns_internal_server_error_on_lookup_failure() {
        let pool = session_test_pool();
        let lookup = SessionLookupSqliteGateway::new(pool.clone());
        let session = lookup.create_for_user(42).expect("session");
        pool.with_write(|conn| conn.execute("DROP TABLE sessions", []))
            .unwrap();
        let state = test_app_state(pool);
        let jar = CookieJar::new().add(Cookie::new("session_id", session.session_id));

        assert_eq!(
            user_id_from_session(&state, &jar),
            Err(StatusCode::INTERNAL_SERVER_ERROR)
        );
    }
}
