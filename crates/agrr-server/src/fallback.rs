//! Unmatched API paths — explicit migration signal (no Rails fallback).

use axum::{
    extract::Request,
    http::StatusCode,
    response::IntoResponse,
    Json,
};
use serde_json::json;

pub async fn api_not_migrated(request: Request) -> impl IntoResponse {
    let path = request.uri().path().to_string();
  (
        StatusCode::NOT_IMPLEMENTED,
        Json(json!({
            "errors": ["api_not_migrated"],
            "path": path
        })),
    )
}