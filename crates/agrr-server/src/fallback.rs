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

#[cfg(test)]
mod tests {
    use super::*;
    use axum::body::{to_bytes, Body};
    use axum::response::IntoResponse;
    use serde_json::Value;

    #[tokio::test]
    async fn api_not_migrated_returns_501_and_echoes_request_path() {
        let request = Request::builder()
            .uri("/api/v1/legacy/unmigrated_endpoint")
            .body(Body::empty())
            .expect("request");

        let response = api_not_migrated(request).await.into_response();
        assert_eq!(response.status(), StatusCode::NOT_IMPLEMENTED);

        let bytes = to_bytes(response.into_body(), usize::MAX)
            .await
            .expect("body bytes");
        let body: Value = serde_json::from_slice(&bytes).expect("json");
        assert_eq!(body["errors"][0], "api_not_migrated");
        assert_eq!(body["path"], "/api/v1/legacy/unmigrated_endpoint");
    }
}