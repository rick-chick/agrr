//! Backdoor HTTP routes (`/api/v1/backdoor/*`).

use crate::adapters::NoopLogger;
use crate::backdoor::build_backdoor_status_json;
use crate::runtime_env;
use crate::security_audit_log::log_backdoor_operation;
use crate::state::AppState;
use agrr_adapters_sqlite::{
    ApplicationDatabaseClearSqliteGateway, BackdoorCreateUserAttrs, BackdoorDiagnosticsSqliteGateway,
    BackdoorUpdateUserAttrs,
};
use agrr_domain::backdoor::interactors::BackdoorClearDatabaseInteractor;
use agrr_domain::backdoor::ports::BackdoorClearDatabaseOutputPort;
use agrr_domain::backdoor::dtos::{BackdoorClearDatabaseFailure, BackdoorClearDatabaseOutput};
use axum::{
    extract::{Path, State},
    http::{HeaderMap, StatusCode},
    routing::{get, patch, post},
    Json, Router,
};
use serde::Deserialize;
use serde_json::{json, Value};
use time::format_description::well_known::Rfc3339;
use time::OffsetDateTime;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/api/v1/backdoor/status", get(status))
        .route("/api/v1/backdoor/health", get(health))
        .route("/api/v1/backdoor/users", get(users).post(create_user))
        .route(
            "/api/v1/backdoor/users/{id}",
            patch(update_user).put(update_user),
        )
        .route("/api/v1/backdoor/db/stats", get(db_stats))
        .route("/api/v1/backdoor/db/clear", post(clear_db))
}

fn timestamp_json() -> String {
    OffsetDateTime::now_utc()
        .format(&Rfc3339)
        .unwrap_or_else(|_| OffsetDateTime::now_utc().to_string())
}

fn backdoor_auth(
    state: &AppState,
    headers: &HeaderMap,
) -> Result<(), (StatusCode, Json<Value>)> {
    if !state.backdoor_enabled() {
        return Err((
            StatusCode::SERVICE_UNAVAILABLE,
            Json(json!({
                "error": "api.errors.backdoor.not_enabled",
                "error_key": "api.errors.backdoor.not_enabled"
            })),
        ));
    }
    let token = headers
        .get("X-Backdoor-Token")
        .and_then(|v| v.to_str().ok());
    let Some(token) = token.filter(|t| !t.is_empty()) else {
        return Err((
            StatusCode::UNAUTHORIZED,
            Json(json!({
                "error": "api.errors.backdoor.missing_token",
                "error_key": "api.errors.backdoor.missing_token"
            })),
        ));
    };
    if !state.backdoor_token_matches(token) {
        return Err((
            StatusCode::FORBIDDEN,
            Json(json!({
                "error": "api.errors.backdoor.invalid_token",
                "error_key": "api.errors.backdoor.invalid_token"
            })),
        ));
    }
    Ok(())
}

fn audit_backdoor_success(action: &str, resource_id: Option<i64>) {
    log_backdoor_operation(action, resource_id, "success");
}

fn audit_backdoor_blocked(action: &str, outcome: &str) {
    log_backdoor_operation(action, None, outcome);
}

async fn status(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    backdoor_auth(&state, &headers)?;
    audit_backdoor_success("status", None);
    let root = std::env::current_dir().unwrap_or_else(|_| ".".into());
    Ok(Json(build_backdoor_status_json(&root)))
}

async fn health(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    backdoor_auth(&state, &headers)?;
    audit_backdoor_success("health", None);
    Ok(Json(json!({
        "status": "ok",
        "timestamp": timestamp_json(),
        "message": "Backdoor API is active"
    })))
}

async fn users(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    backdoor_auth(&state, &headers)?;
    let gw = BackdoorDiagnosticsSqliteGateway::new(state.sqlite.clone());
    let payload = gw.users_list_payload().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "error": "internal"})),
        )
    })?;
    audit_backdoor_success("users_list", None);
    Ok(Json(json!({
        "timestamp": timestamp_json(),
        "total_users": payload.total_users,
        "users": payload.users
    })))
}

#[derive(Deserialize)]
struct UserBody {
    user: UserAttrs,
}

#[derive(Deserialize)]
struct UserAttrs {
    email: Option<String>,
    name: Option<String>,
    google_id: Option<String>,
    avatar_url: Option<String>,
    #[serde(default)]
    admin: Option<bool>,
}

async fn create_user(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<UserBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    backdoor_auth(&state, &headers)?;
    let gw = BackdoorDiagnosticsSqliteGateway::new(state.sqlite.clone());
    let attrs = BackdoorCreateUserAttrs {
        email: body.user.email,
        name: body.user.name,
        google_id: body.user.google_id,
        avatar_url: body.user.avatar_url,
        admin: body.user.admin.unwrap_or(false),
    };
    match gw.create_user(attrs).map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "error": "internal"})),
        )
    })? {
        agrr_adapters_sqlite::BackdoorCreateUserResult::Ok { user } => {
            audit_backdoor_success("user_create", Some(user.id));
            Ok((
            StatusCode::CREATED,
            Json(json!({
                "timestamp": timestamp_json(),
                "success": true,
                "user": user
            })),
        ))
        }
        agrr_adapters_sqlite::BackdoorCreateUserResult::Invalid { errors } => Ok((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({
                "timestamp": timestamp_json(),
                "success": false,
                "errors": errors
            })),
        )),
    }
}

async fn update_user(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<i64>,
    Json(body): Json<UserBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    backdoor_auth(&state, &headers)?;
    let gw = BackdoorDiagnosticsSqliteGateway::new(state.sqlite.clone());
    let attrs = BackdoorUpdateUserAttrs {
        email: body.user.email,
        name: body.user.name,
        google_id: body.user.google_id,
        avatar_url: body.user.avatar_url,
        admin: body.user.admin,
    };
    match gw.update_user(id, attrs).map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "error": "internal"})),
        )
    })? {
        agrr_adapters_sqlite::BackdoorUpdateUserResult::Ok { user } => {
            audit_backdoor_success("user_update", Some(user.id));
            Ok((
            StatusCode::OK,
            Json(json!({
                "timestamp": timestamp_json(),
                "success": true,
                "user": user
            })),
        ))
        }
        agrr_adapters_sqlite::BackdoorUpdateUserResult::NotFound => Ok((
            StatusCode::NOT_FOUND,
            Json(json!({
                "timestamp": timestamp_json(),
                "success": false,
                "error": "User not found"
            })),
        )),
        agrr_adapters_sqlite::BackdoorUpdateUserResult::Invalid { errors } => Ok((
            StatusCode::UNPROCESSABLE_ENTITY,
            Json(json!({
                "timestamp": timestamp_json(),
                "success": false,
                "errors": errors
            })),
        )),
    }
}

async fn db_stats(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    backdoor_auth(&state, &headers)?;
    let gw = BackdoorDiagnosticsSqliteGateway::new(state.sqlite.clone());
    let stats = gw.db_stats_counts().map_err(|_| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "error": "internal"})),
        )
    })?;
    audit_backdoor_success("db_stats", None);
    Ok(Json(json!({
        "timestamp": timestamp_json(),
        "stats": stats,
        "warning": "⚠️ Clearing database will delete ALL data except anonymous users"
    })))
}

#[derive(Deserialize)]
struct ClearDbBody {
    confirmation_token: Option<String>,
}

struct ClearDbPresenter {
    response: Option<(StatusCode, Json<Value>)>,
}

impl BackdoorClearDatabaseOutputPort for ClearDbPresenter {
    fn on_success(&mut self, output: BackdoorClearDatabaseOutput) {
        self.response = Some((
            StatusCode::OK,
            Json(json!({
                "timestamp": timestamp_json(),
                "success": true,
                "message": "Database cleared successfully",
                "before_stats": stats_json(&output.before_stats),
                "after_stats": stats_json(&output.after_stats),
                "warning": "⚠️ All data has been deleted. This action is irreversible."
            })),
        ));
    }

    fn on_failure(&mut self, failure: BackdoorClearDatabaseFailure) {
        self.response = Some((
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({
                "timestamp": timestamp_json(),
                "success": false,
                "error": failure.message
            })),
        ));
    }
}

fn stats_json(stats: &agrr_domain::backdoor::gateways::ApplicationDataStats) -> Value {
    json!({
        "users": stats.users,
        "farms": stats.farms,
        "fields": stats.fields,
        "crops": stats.crops,
        "cultivation_plans": stats.cultivation_plans
    })
}

async fn clear_db(
    State(state): State<AppState>,
    headers: HeaderMap,
    Json(body): Json<ClearDbBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    backdoor_auth(&state, &headers)?;
    if !backdoor_db_clear_allowed() {
        audit_backdoor_blocked("db_clear", "blocked_production");
        return Err((
            StatusCode::FORBIDDEN,
            Json(json!({
                "timestamp": timestamp_json(),
                "success": false,
                "error": "api.errors.backdoor.db_clear_forbidden_in_production",
                "error_key": "api.errors.backdoor.db_clear_forbidden_in_production",
                "message": "db/clear is disabled in production. Use Litestream restore or a break-glass runbook instead."
            })),
        ));
    }
    let Some(token) = body.confirmation_token.as_deref().filter(|t| !t.is_empty()) else {
        return Ok((
            StatusCode::BAD_REQUEST,
            Json(json!({
                "timestamp": timestamp_json(),
                "success": false,
                "error": "Missing confirmation_token parameter",
                "warning": "⚠️ This operation will DELETE ALL DATA. Provide confirmation_token matching your backdoor token."
            })),
        ));
    };
    if !state.backdoor_token_matches(token) {
        return Ok((
            StatusCode::FORBIDDEN,
            Json(json!({
                "timestamp": timestamp_json(),
                "success": false,
                "error": "Invalid confirmation_token",
                "warning": "confirmation_token must match your backdoor token for security"
            })),
        ));
    }
    let gateway = ApplicationDatabaseClearSqliteGateway::new(state.sqlite.clone());
    let logger = NoopLogger;
    let mut presenter = ClearDbPresenter { response: None };
    let mut interactor = BackdoorClearDatabaseInteractor::new(&mut presenter, &gateway, &logger);
    interactor.call();
    if let Some((status, _)) = presenter.response.as_ref() {
        if *status == StatusCode::OK {
            audit_backdoor_success("db_clear", None);
        } else {
            audit_backdoor_blocked("db_clear", "failure");
        }
    }
    presenter.response.ok_or_else(|| {
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "error": "no response"})),
        )
    })
}

pub(crate) fn backdoor_db_clear_allowed() -> bool {
    !runtime_env::is_production()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn backdoor_db_clear_allowed_respects_runtime_env() {
        let prev_env = std::env::var("AGRR_ENV").ok();
        let prev_rails = std::env::var("RAILS_ENV").ok();

        std::env::set_var("AGRR_ENV", "production");
        std::env::remove_var("RAILS_ENV");
        assert!(!backdoor_db_clear_allowed());

        std::env::set_var("AGRR_ENV", "development");
        std::env::remove_var("RAILS_ENV");
        assert!(backdoor_db_clear_allowed());

        restore_env("AGRR_ENV", prev_env);
        restore_env("RAILS_ENV", prev_rails);
    }

    fn restore_env(key: &str, value: Option<String>) {
        match value {
            Some(v) => std::env::set_var(key, v),
            None => std::env::remove_var(key),
        }
    }
}
