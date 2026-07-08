//! Nested crop agricultural task templates — `/api/v1/masters/crops/{crop_id}/agricultural_tasks`.
//!
//! Deprecated in Phase 4: task templates replaced by task schedule blueprints.

use crate::state::AppState;
use axum::{
    http::StatusCode,
    routing::get,
    Json, Router,
};
use serde_json::{json, Value};

pub fn routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/masters/crops/{crop_id}/agricultural_tasks",
            get(gone).post(gone),
        )
        .route(
            "/api/v1/masters/crops/{crop_id}/agricultural_tasks/{id}",
            axum::routing::put(gone).patch(gone).delete(gone),
        )
}

async fn gone() -> (StatusCode, Json<Value>) {
    (
        StatusCode::GONE,
        Json(json!({
            "error": "Crop task templates were replaced by task schedule blueprints",
            "error_code": "crop_task_template_api_removed"
        })),
    )
}
