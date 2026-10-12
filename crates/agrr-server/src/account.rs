//! `GET /api/v1/account/export` and `DELETE /api/v1/account`.

use std::sync::{Arc, Mutex};

use crate::session_auth::user_id_from_session;
use crate::state::AppState;
use crate::work_record_photos::work_record_photo_store;
use agrr_adapters_sqlite::{UserAccountSqliteGateway, UserSessionRevocationSqliteGateway};
use agrr_domain::user_account::dtos::UserAccountDeleteInput;
use agrr_domain::user_account::interactors::{
    UserAccountDeleteInteractor, UserDataExportInteractor,
};
use agrr_domain::user_account::ports::{
    UserAccountDeleteOutputPort, UserDataExportOutputPort,
};
use axum::{
    extract::State,
    http::StatusCode,
    response::IntoResponse,
    routing::{delete, get},
    Json, Router,
};
use axum_extra::extract::cookie::{Cookie, CookieJar};
use serde::Deserialize;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/account/export", get(export_data))
        .route("/api/v1/account", delete(delete_account))
}

struct ExportPresenter {
    body: Arc<Mutex<Option<Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)>>>>,
}

impl UserDataExportOutputPort for ExportPresenter {
    fn on_success(&mut self, export: agrr_domain::user_account::dtos::UserDataExport) {
        *self.body.lock().unwrap() = Some(Ok(Json(
            serde_json::to_value(export).unwrap_or(serde_json::json!({})),
        )));
    }

    fn on_failure(&mut self, failure: agrr_domain::user_account::dtos::UserDataExportFailure) {
        *self.body.lock().unwrap() = Some(Err((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(serde_json::json!({ "errors": [failure.message]})),
        )));
    }
}

struct DeletePresenter {
    body: Arc<Mutex<Option<(StatusCode, Json<serde_json::Value>, bool)>>>,
}

impl UserAccountDeleteOutputPort for DeletePresenter {
    fn on_success(&mut self) {
        *self.body.lock().unwrap() =
            Some((StatusCode::OK, Json(serde_json::json!({ "success": true })), true));
    }

    fn on_not_confirmed(&mut self) {
        *self.body.lock().unwrap() = Some((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(serde_json::json!({
                "errors": ["confirmation_required", "Set confirm to true"]
            })),
            false,
        ));
    }

    fn on_failure(&mut self, message: String) {
        let status = if message.contains("Email") {
            StatusCode::UNPROCESSABLE_ENTITY
        } else {
            StatusCode::INTERNAL_SERVER_ERROR
        };
        *self.body.lock().unwrap() = Some((status, Json(serde_json::json!({ "errors": [message]})), false));
    }
}

#[derive(Deserialize)]
struct DeleteAccountBody {
    confirm: bool,
    #[serde(default)]
    email_confirm: Option<String>,
}

async fn export_data(
    State(state): State<AppState>,
    jar: CookieJar,
) -> Result<Json<serde_json::Value>, (StatusCode, Json<serde_json::Value>)> {
    let user_id = user_id_from_session(&state, &jar).map_err(|status| {
        (
            status,
            Json(serde_json::json!({"errors": ["unauthorized"]})),
        )
    })?;
    let gateway = UserAccountSqliteGateway::new(state.sqlite.clone());
    let body = Arc::new(Mutex::new(None));
    let mut presenter = ExportPresenter { body: body.clone() };
    let mut interactor = UserDataExportInteractor::new(&mut presenter, &gateway);
    interactor.call(user_id).map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(serde_json::json!({"errors": ["internal"]})),
        )
    })?;
    let result = body.lock().unwrap().take();
    result.unwrap_or(Err((
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(serde_json::json!({"errors": ["internal"]})),
    )))
}

async fn delete_account(
    State(state): State<AppState>,
    jar: CookieJar,
    Json(payload): Json<DeleteAccountBody>,
) -> impl IntoResponse {
    let user_id = match user_id_from_session(&state, &jar) {
        Ok(id) => id,
        Err(status) => {
            return (
                jar,
                (
                    status,
                    Json(serde_json::json!({"errors": ["unauthorized"]})),
                ),
            )
                .into_response();
        }
    };

    let account_gateway = UserAccountSqliteGateway::new(state.sqlite.clone());
    let session_gateway = UserSessionRevocationSqliteGateway::new(state.sqlite.clone());
    let photo_store = match work_record_photo_store() {
        Ok(store) => store,
        Err((status, json)) => return (jar, (status, json)).into_response(),
    };

    let body = Arc::new(Mutex::new(None));
    let mut presenter = DeletePresenter { body: body.clone() };
    let mut interactor = UserAccountDeleteInteractor::new(
        &mut presenter,
        &account_gateway,
        &session_gateway,
        photo_store.as_ref(),
    );
    let input = UserAccountDeleteInput {
        user_id,
        confirm: payload.confirm,
        email_confirm: payload.email_confirm,
    };
    if interactor.call(input).is_err() {
        return (
            jar,
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"errors": ["internal"]})),
            ),
        )
            .into_response();
    }

    let Some((status, json, clear_cookie)) = body.lock().unwrap().take() else {
        return (
            jar,
            (
                StatusCode::INTERNAL_SERVER_ERROR,
                Json(serde_json::json!({"errors": ["internal"]})),
            ),
        )
            .into_response();
    };

    let jar = if clear_cookie {
        jar.remove(Cookie::from("session_id"))
    } else {
        jar
    };
    (jar, (status, json)).into_response()
}

#[cfg(test)]
mod tests {
    use super::*;
    use agrr_domain::user_account::dtos::{UserDataExport, UserDataExportFailure, UserExportSnapshot};
    use agrr_domain::user_account::ports::UserDataExportOutputPort;

    fn sample_export() -> UserDataExport {
        UserDataExport {
            exported_at: "2026-01-01T00:00:00Z".into(),
            user: UserExportSnapshot {
                id: 42,
                email: Some("user@example.com".into()),
                name: Some("Test User".into()),
                created_at: None,
            },
            farms: vec![serde_json::json!({ "id": 1, "name": "Farm" })],
            crops: vec![],
            cultivation_plans: vec![],
        }
    }

    // Locks docs/spec-defects/06 S3/G: export success must not collapse to `{}` on serialize.
    #[test]
    fn export_presenter_on_success_includes_export_payload_without_legacy_keys() {
        let body = Arc::new(Mutex::new(None));
        let mut presenter = ExportPresenter { body: body.clone() };
        presenter.on_success(sample_export());

        let json = body
            .lock()
            .unwrap()
            .take()
            .expect("presenter wrote body")
            .expect("success status");
        assert_eq!(json["user"]["id"], 42);
        assert_eq!(json["exported_at"], "2026-01-01T00:00:00Z");
        assert_eq!(json["farms"].as_array().expect("farms").len(), 1);
        assert!(json.get("error").is_none());
        assert!(json.get("message").is_none());
    }

    #[test]
    fn export_presenter_on_failure_uses_errors_array() {
        let body = Arc::new(Mutex::new(None));
        let mut presenter = ExportPresenter { body: body.clone() };
        presenter.on_failure(UserDataExportFailure::new("export_denied"));

        let (status, Json(err_body)) = body
            .lock()
            .unwrap()
            .take()
            .expect("presenter wrote body")
            .expect_err("failure status");
        assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
        assert_eq!(err_body["errors"][0], "export_denied");
        assert!(err_body.get("error").is_none());
        assert!(err_body.get("message").is_none());
    }
}