//! HTTP API routes (BC slices) not yet owned by feature modules.

use crate::optimization_job_chain::enqueue_scheduler_weather_update_chain;
use crate::state::AppState;
use axum::{
    extract::State,
    http::{header, HeaderMap, StatusCode},
    response::IntoResponse,
    routing::post,
    Json, Router,
};

pub fn api_routes() -> Router<AppState> {
    Router::new()
        .route(
            "/api/v1/internal/jobs/trigger_weather_update",
            post(trigger_weather_update),
        )
}

async fn trigger_weather_update(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> impl IntoResponse {
    let token = headers
        .get("X-Scheduler-Token")
        .and_then(|v| v.to_str().ok())
        .or_else(|| {
            headers
                .get(header::AUTHORIZATION)
                .and_then(|v| v.to_str().ok())
                .and_then(|v| v.strip_prefix("Bearer "))
        });
    let Some(token) = token else {
        return (
            StatusCode::UNAUTHORIZED,
            Json(serde_json::json!({"error": "Missing authentication token"})),
        )
            .into_response();
    };
    if state.scheduler_auth_token.is_empty() || token != state.scheduler_auth_token.as_str() {
        return (
            StatusCode::FORBIDDEN,
            Json(serde_json::json!({"error": "Invalid authentication token"})),
        )
            .into_response();
    }
    enqueue_scheduler_weather_update_chain(&state);
    (
        StatusCode::OK,
        Json(serde_json::json!({
            "success": true,
            "message": "Weather update jobs enqueued",
            "timestamp": time::OffsetDateTime::now_utc().unix_timestamp()
        })),
    )
        .into_response()
}

