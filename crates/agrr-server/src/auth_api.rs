//! JSON API auth routes (`GET /api/v1/auth/me`).

use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::SessionUserReadSqliteGateway;
use agrr_adapters_sqlite::UserSessionRevocationSqliteGateway;
use agrr_domain::auth::interactors::AuthUserLogoutInteractor;
use agrr_domain::auth::ports::AuthUserLogoutOutputPort;
use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::{delete, get},
    Json, Router,
};
use axum_extra::extract::cookie::{Cookie, CookieJar};
use serde::Serialize;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/auth/me", get(auth_me))
        .route("/api/v1/auth/logout", delete(auth_logout))
}

struct LogoutPresenter;

impl AuthUserLogoutOutputPort for LogoutPresenter {
    fn on_success(&mut self) {}
    fn on_not_logged_in(&mut self) {}
}

#[derive(Serialize)]
struct MeResponse {
    user: MeUser,
}

#[derive(Serialize)]
struct MeUser {
    id: i64,
    name: Option<String>,
    email: Option<String>,
    avatar_url: Option<String>,
    admin: bool,
    api_key: Option<String>,
}

async fn auth_logout(
    State(state): State<AppState>,
    jar: CookieJar,
) -> impl IntoResponse {
    let user_id = crate::session_auth::user_id_from_session(&state, &jar).ok();
    let authenticated = user_id.is_some();
    let gateway = UserSessionRevocationSqliteGateway::new(state.sqlite.clone());
    let mut presenter = LogoutPresenter;
    let mut interactor = AuthUserLogoutInteractor::new(&mut presenter, &gateway);
    interactor.call(authenticated, user_id.unwrap_or(0));
    let jar = jar.remove(Cookie::from("session_id"));
    (
        jar,
        Json(serde_json::json!({"success": true})),
    )
}

async fn auth_me(
    State(state): State<AppState>,
    jar: CookieJar,
) -> Result<Json<MeResponse>, (StatusCode, Json<serde_json::Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(serde_json::json!({"error": "unauthorized"})),
        )
    })?;
    let gateway = SessionUserReadSqliteGateway::new(state.sqlite.clone());
    let row = gateway.find_by_id(user_id).map_err(|_| {
        (
            StatusCode::UNAUTHORIZED,
            Json(serde_json::json!({"error": "unauthorized"})),
        )
    })?;
    Ok(Json(MeResponse {
        user: MeUser {
            id: row.id,
            name: row.name,
            email: row.email,
            avatar_url: row.avatar_url,
            admin: row.admin,
            api_key: row.api_key,
        },
    }))
}
