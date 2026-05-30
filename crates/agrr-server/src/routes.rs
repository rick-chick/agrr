//! HTTP API routes (BC slices) not yet owned by feature modules.

use crate::optimization_job_chain::enqueue_scheduler_weather_update_chain;
use crate::state::AppState;
use axum::{
    extract::State,
    http::{header, HeaderMap, StatusCode},
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use time::format_description::well_known::Rfc3339;
use time::OffsetDateTime;

pub fn api_routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/health", get(api_v1_health))
        .route(
            "/api/v1/internal/jobs/trigger_weather_update",
            post(trigger_weather_update),
        )
}

async fn api_v1_health() -> Json<serde_json::Value> {
    let timestamp = OffsetDateTime::now_utc()
        .format(&Rfc3339)
        .unwrap_or_else(|_| OffsetDateTime::now_utc().to_string());
    let environment = std::env::var("RAILS_ENV")
        .or_else(|_| std::env::var("AGRR_ENV"))
        .unwrap_or_else(|_| "production".into());
    Json(serde_json::json!({
        "status": "ok",
        "database": "sqlite3",
        "storage": "connected",
        "timestamp": timestamp,
        "environment": environment,
        "version": "1.0.0"
    }))
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

