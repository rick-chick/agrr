//! `POST /api/v1/api_keys/generate` and `/regenerate`.

use crate::security_audit_log::{log_api_key_generate, log_api_key_regenerate};
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
        *self.body.lock().unwrap() = Some((status, Json(serde_json::json!({ "errors": [message]}))));
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
            Json(serde_json::json!({"errors": ["unauthorized"]})),
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
    let response = guard.take().ok_or((
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(serde_json::json!({"errors": ["internal"]})),
    ))?;
    if response.0 == StatusCode::OK {
        if regenerate {
            log_api_key_regenerate(user_id);
        } else {
            log_api_key_generate(user_id);
        }
    }
    Ok(response)
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::api_keys::ports::UserApiKeyRotateOutputPort;

    #[test]
    fn rotate_presenter_on_success_returns_api_key_json() {
        let body = Arc::new(Mutex::new(None));
        let mut presenter = RotatePresenter { body: body.clone() };
        presenter.on_success("agr_live_key".into());

        let (status, Json(json)) = body.lock().unwrap().take().expect("presenter wrote body");
        assert_eq!(status, StatusCode::OK);
        assert_eq!(json["api_key"], "agr_live_key");
    }

    #[test]
    fn rotate_presenter_on_failure_not_found_is_404() {
        let body = Arc::new(Mutex::new(None));
        let mut presenter = RotatePresenter { body: body.clone() };
        presenter.on_failure("user not found".into());

        let (status, Json(json)) = body.lock().unwrap().take().expect("presenter wrote body");
        assert_eq!(status, StatusCode::NOT_FOUND);
        assert_eq!(json["errors"][0], "user not found");
    }

    #[test]
    fn rotate_presenter_on_failure_other_is_422() {
        let body = Arc::new(Mutex::new(None));
        let mut presenter = RotatePresenter { body: body.clone() };
        presenter.on_failure("rotation blocked".into());

        let (status, Json(json)) = body.lock().unwrap().take().expect("presenter wrote body");
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(json["errors"][0], "rotation blocked");
    }
}