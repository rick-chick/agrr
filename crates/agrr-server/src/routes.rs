//! HTTP API routes (BC slices) not yet owned by feature modules.

use crate::scheduler_weather_update::trigger_scheduler_weather_update;
use crate::state::AppState;
use axum::{
    extract::{Query, State},
    http::{header, HeaderMap, StatusCode},
    response::IntoResponse,
    routing::{get, post},
    Json, Router,
};
use serde::Deserialize;
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

#[derive(Debug, Deserialize)]
struct SchedulerTokenQuery {
    token: Option<String>,
}

fn extract_scheduler_token(headers: &HeaderMap, query: &SchedulerTokenQuery) -> Option<String> {
    if let Some(token) = headers
        .get("X-Scheduler-Token")
        .and_then(|v| v.to_str().ok())
        .map(str::to_string)
    {
        return Some(token);
    }
    if let Some(token) = headers
        .get(header::AUTHORIZATION)
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .map(str::to_string)
    {
        return Some(token);
    }
    query.token.clone()
}

async fn trigger_weather_update(
    State(state): State<AppState>,
    headers: HeaderMap,
    Query(query): Query<SchedulerTokenQuery>,
) -> impl IntoResponse {
    if state.scheduler_auth_token.is_empty() {
        return (
            StatusCode::SERVICE_UNAVAILABLE,
            Json(serde_json::json!({"error": "Authentication not configured"})),
        )
            .into_response();
    }

    let Some(provided_token) = extract_scheduler_token(&headers, &query) else {
        return (
            StatusCode::UNAUTHORIZED,
            Json(serde_json::json!({"error": "Missing authentication token"})),
        )
            .into_response();
    };

    if provided_token != state.scheduler_auth_token.as_str() {
        return (
            StatusCode::FORBIDDEN,
            Json(serde_json::json!({"error": "Invalid authentication token"})),
        )
            .into_response();
    }

    trigger_scheduler_weather_update(&state)
}
