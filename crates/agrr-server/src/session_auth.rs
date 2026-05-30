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
