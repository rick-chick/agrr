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
use serde::Deserialize;
use std::sync::{Arc, Mutex};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/api_keys/generate", post(generate))
        .route("/api/v1/api_keys/regenerate", post(regenerate))
}

#[derive(Debug, Deserialize, Default)]
struct ApiKeyRotateBody {
    scopes: Option<Vec<String>>,
}

struct RotatePresenter {
    body: Arc<Mutex<Option<(StatusCode, Json<serde_json::Value>)>>>,
}

impl UserApiKeyRotateOutputPort for RotatePresenter {
    fn on_success(&mut self, api_key: String, scopes: Vec<String>) {
        *self.body.lock().unwrap() = Some((
            StatusCode::OK,
            Json(serde_json::json!({ "api_key": api_key, "scopes": scopes })),
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
    body: Option<Json<ApiKeyRotateBody>>,
) -> Result<(StatusCode, Json<serde_json::Value>), (StatusCode, Json<serde_json::Value>)> {
    rotate(state, jar, false, body).await
}

async fn regenerate(
    State(state): State<AppState>,
    jar: CookieJar,
    body: Option<Json<ApiKeyRotateBody>>,
) -> Result<(StatusCode, Json<serde_json::Value>), (StatusCode, Json<serde_json::Value>)> {
    rotate(state, jar, true, body).await
}

async fn rotate(
    state: AppState,
    jar: CookieJar,
    regenerate: bool,
    body: Option<Json<ApiKeyRotateBody>>,
) -> Result<(StatusCode, Json<serde_json::Value>), (StatusCode, Json<serde_json::Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(serde_json::json!({"error": "unauthorized"})),
        )
    })?;
    let scopes = body.map(|b| b.scopes.clone()).unwrap_or_default();
    let gateway = UserApiKeyRotationSqliteGateway::new(state.sqlite.clone());
    let body_store = Arc::new(Mutex::new(None));
    let presenter = RotatePresenter {
        body: body_store.clone(),
    };
    let mut interactor = UserApiKeyRotateInteractor::new(Box::new(presenter), gateway);
    interactor.call(user_id, regenerate, scopes);
    let mut guard = body_store.lock().unwrap();
    guard.take().ok_or((
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(serde_json::json!({"error": "internal"})),
    ))
}
