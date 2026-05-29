//! `POST /undo_deletion` — restore a soft-deleted resource (JSON API).

use crate::adapters::SystemClock;
use crate::state::AppState;
use agrr_adapters_sqlite::DeletionUndoSqliteGateway;
use agrr_domain::deletion_undo::dtos::{DeletionUndoRestoreInput, DeletionUndoRestoreOutput};
use agrr_domain::deletion_undo::interactors::DeletionUndoRestoreInteractor;
use agrr_domain::deletion_undo::ports::DeletionUndoRestoreOutputPort;
use agrr_domain::shared::dtos::Error;
use axum::{
    extract::State,
    http::StatusCode,
    routing::post,
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new().route("/undo_deletion", post(restore))
}

#[derive(Deserialize)]
struct RestoreBody {
    undo_token: String,
}

struct RestorePresenter {
    status: StatusCode,
    body: Value,
}

impl DeletionUndoRestoreOutputPort for RestorePresenter {
    fn on_success(&mut self, output: DeletionUndoRestoreOutput) {
        self.status = StatusCode::OK;
        self.body = json!({
            "status": output.status,
            "undo_token": output.undo_token,
        });
    }

    fn on_failure(&mut self, error: Error) {
        let msg = error.message;
        let (status, display) = classify_restore_error(&msg);
        self.status = status;
        self.body = json!({ "status": "error", "error": display });
    }
}

fn classify_restore_error(message: &str) -> (StatusCode, String) {
    let lower = message.to_lowercase();
    if lower.contains("not found") {
        (StatusCode::NOT_FOUND, message.to_string())
    } else if lower.contains("expired") || lower.contains("token") {
        (
            StatusCode::UNPROCESSABLE_ENTITY,
            "Undo token has expired".to_string(),
        )
    } else if lower.contains("conflict") {
        (StatusCode::CONFLICT, message.to_string())
    } else {
        (StatusCode::INTERNAL_SERVER_ERROR, message.to_string())
    }
}

async fn restore(
    State(state): State<AppState>,
    Json(body): Json<RestoreBody>,
) -> (StatusCode, Json<Value>) {
    let gateway = DeletionUndoSqliteGateway::new(state.sqlite.clone());
    let clock = SystemClock;
    let mut presenter = RestorePresenter {
        status: StatusCode::INTERNAL_SERVER_ERROR,
        body: json!({"status": "error", "error": "no response"}),
    };
    let input = DeletionUndoRestoreInput::new(body.undo_token);
    let mut interactor =
        DeletionUndoRestoreInteractor::new(&mut presenter, &gateway, &clock);
    interactor.call(input);
    (presenter.status, Json(presenter.body))
}
