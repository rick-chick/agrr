//! `POST /api/v1/api_keys/generate` and `/regenerate`.

use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use agrr_adapters_sqlite::UserApiKeyRotationSqliteGateway;
use agrr_domain::api_keys::interactors::UserApiKeyRotateInteractor;
use agrr_domain::api_keys::ports::UserApiKeyRotateOutputPort;
use axum::{
    extract::State,
    http::StatusCode,
    routing::post,
    Json, Router,
};
use axum_extra::extract::cookie::CookieJar;
use std::sync::{Arc, Mutex};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/api_keys/generate", post(generate))
        .route("/api/v1/api_keys/regenerate", post(regenerate))
}

struct RotatePresenter {
    body: Arc<Mutex<Option<(StatusCode, Json<serde_json::Value>)>>>,
}

impl UserApiKeyRotateOutputPort for RotatePresenter {
    fn on_success(&mut self, api_key: String) {
        *self.body.lock().unwrap() = Some((
            StatusCode::OK,
            Json(serde_json::json!({ "api_key": api_key })),
        ));
    }

    fn on_failure(&mut self, message: String) {
        let status = if message.contains("not found") {
            StatusCode::NOT_FOUND
        } else {
            StatusCode::UNPROCESSABLE_ENTITY
        };
        *self.body.lock().unwrap() = Some((status, Json(serde_json::json!({ "error": message }))));
    }
}

async fn generate(
    State(state): State<AppState>,
    jar: CookieJar,
) -> Result<(StatusCode, Json<serde_json::Value>), (StatusCode, Json<serde_json::Value>)> {
    rotate(state, jar, false).await
}

async fn regenerate(
    State(state): State<AppState>,
    jar: CookieJar,
) -> Result<(StatusCode, Json<serde_json::Value>), (StatusCode, Json<serde_json::Value>)> {
    rotate(state, jar, true).await
}

async fn rotate(
    state: AppState,
    jar: CookieJar,
    regenerate: bool,
) -> Result<(StatusCode, Json<serde_json::Value>), (StatusCode, Json<serde_json::Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(serde_json::json!({"error": "unauthorized"})),
        )
    })?;
    let gateway = UserApiKeyRotationSqliteGateway::new(state.sqlite.clone());
    let body = Arc::new(Mutex::new(None));
    let presenter = RotatePresenter {
        body: body.clone(),
    };
    let mut interactor = UserApiKeyRotateInteractor::new(Box::new(presenter), gateway);
    interactor.call(user_id, regenerate);
    let mut guard = body.lock().unwrap();
    guard.take().ok_or((
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(serde_json::json!({"error": "internal"})),
    ))
}
