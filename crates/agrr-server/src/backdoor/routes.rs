//! Backdoor HTTP routes (`/api/v1/backdoor/*`).

use crate::adapters::NoopLogger;
use crate::backdoor::build_backdoor_status_json;
use crate::runtime_env;
use crate::security_audit_log::{log_backdoor_auth_failure, log_backdoor_operation};
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

/// Returns true when a create-user request would grant admin privileges.
fn create_user_requests_admin_grant(admin: Option<bool>) -> bool {
    admin.unwrap_or(false)
}

/// Returns true when an update-user request includes an admin flag change.
fn update_user_requests_admin_change(admin: Option<bool>) -> bool {
    admin.is_some()
}

fn admin_change_denied_response() -> (StatusCode, Json<Value>) {
    (
        StatusCode::FORBIDDEN,
        Json(json!({
            "timestamp": timestamp_json(),
            "success": false,
            "error": "api.errors.backdoor.admin_change_disabled_in_production",
            "error_key": "api.errors.backdoor.admin_change_disabled_in_production",
            "warning": "Admin grant/revoke is disabled in production unless AGRR_BACKDOOR_ALLOW_ADMIN_CHANGES=1 is set for break-glass use"
        })),
    )
}

fn db_clear_denied_response() -> (StatusCode, Json<Value>) {
    (
        StatusCode::FORBIDDEN,
        Json(json!({
            "timestamp": timestamp_json(),
            "success": false,
            "error": "api.errors.backdoor.db_clear_disabled_in_production",
            "error_key": "api.errors.backdoor.db_clear_disabled_in_production",
            "warning": "db/clear is disabled in production unless AGRR_BACKDOOR_ALLOW_DB_CLEAR=1 is set for break-glass use"
        })),
    )
}

fn backdoor_auth(
    state: &AppState,
    headers: &HeaderMap,
) -> Result<(), (StatusCode, Json<Value>)> {
    if !state.backdoor_enabled() {
        log_backdoor_auth_failure("not_enabled");
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
        log_backdoor_auth_failure("missing_token");
        return Err((
            StatusCode::UNAUTHORIZED,
            Json(json!({
                "error": "api.errors.backdoor.missing_token",
                "error_key": "api.errors.backdoor.missing_token"
            })),
        ));
    };
    if !state.backdoor_token_matches(token) {
        log_backdoor_auth_failure("invalid_token");
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

async fn status(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    backdoor_auth(&state, &headers)?;
    let root = std::env::current_dir().unwrap_or_else(|_| ".".into());
    log_backdoor_operation("status", "success", None);
    Ok(Json(build_backdoor_status_json(&root)))
}

async fn health(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    backdoor_auth(&state, &headers)?;
    log_backdoor_operation("health", "success", None);
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
        log_backdoor_operation("users_list", "error", None);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "error": "internal"})),
        )
    })?;
    log_backdoor_operation("users_list", "success", None);
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
    if create_user_requests_admin_grant(body.user.admin)
        && !runtime_env::backdoor_admin_changes_allowed()
    {
        log_backdoor_operation("user_create", "blocked_production_admin", None);
        return Ok(admin_change_denied_response());
    }
    let gw = BackdoorDiagnosticsSqliteGateway::new(state.sqlite.clone());
    let attrs = BackdoorCreateUserAttrs {
        email: body.user.email,
        name: body.user.name,
        google_id: body.user.google_id,
        avatar_url: body.user.avatar_url,
        admin: body.user.admin.unwrap_or(false),
    };
    match gw.create_user(attrs).map_err(|_| {
        log_backdoor_operation("user_create", "error", None);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "error": "internal"})),
        )
    })? {
        agrr_adapters_sqlite::BackdoorCreateUserResult::Ok { user } => {
            log_backdoor_operation("user_create", "success", Some(user.id));
            Ok((
                StatusCode::CREATED,
                Json(json!({
                    "timestamp": timestamp_json(),
                    "success": true,
                    "user": user
                })),
            ))
        }
        agrr_adapters_sqlite::BackdoorCreateUserResult::Invalid { errors } => {
            log_backdoor_operation("user_create", "invalid", None);
            Ok((
                StatusCode::UNPROCESSABLE_ENTITY,
                Json(json!({
                    "timestamp": timestamp_json(),
                    "success": false,
                    "errors": errors
                })),
            ))
        }
    }
}

async fn update_user(
    State(state): State<AppState>,
    headers: HeaderMap,
    Path(id): Path<i64>,
    Json(body): Json<UserBody>,
) -> Result<(StatusCode, Json<Value>), (StatusCode, Json<Value>)> {
    backdoor_auth(&state, &headers)?;
    if update_user_requests_admin_change(body.user.admin)
        && !runtime_env::backdoor_admin_changes_allowed()
    {
        log_backdoor_operation("user_update", "blocked_production_admin", Some(id));
        return Ok(admin_change_denied_response());
    }
    let gw = BackdoorDiagnosticsSqliteGateway::new(state.sqlite.clone());
    let attrs = BackdoorUpdateUserAttrs {
        email: body.user.email,
        name: body.user.name,
        google_id: body.user.google_id,
        avatar_url: body.user.avatar_url,
        admin: body.user.admin,
    };
    match gw.update_user(id, attrs).map_err(|_| {
        log_backdoor_operation("user_update", "error", Some(id));
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "error": "internal"})),
        )
    })? {
        agrr_adapters_sqlite::BackdoorUpdateUserResult::Ok { user } => {
            log_backdoor_operation("user_update", "success", Some(id));
            Ok((
                StatusCode::OK,
                Json(json!({
                    "timestamp": timestamp_json(),
                    "success": true,
                    "user": user
                })),
            ))
        }
        agrr_adapters_sqlite::BackdoorUpdateUserResult::NotFound => {
            log_backdoor_operation("user_update", "not_found", Some(id));
            Ok((
                StatusCode::NOT_FOUND,
                Json(json!({
                    "timestamp": timestamp_json(),
                    "success": false,
                    "error": "User not found"
                })),
            ))
        }
        agrr_adapters_sqlite::BackdoorUpdateUserResult::Invalid { errors } => {
            log_backdoor_operation("user_update", "invalid", Some(id));
            Ok((
                StatusCode::UNPROCESSABLE_ENTITY,
                Json(json!({
                    "timestamp": timestamp_json(),
                    "success": false,
                    "errors": errors
                })),
            ))
        }
    }
}

async fn db_stats(
    State(state): State<AppState>,
    headers: HeaderMap,
) -> Result<Json<Value>, (StatusCode, Json<Value>)> {
    backdoor_auth(&state, &headers)?;
    let gw = BackdoorDiagnosticsSqliteGateway::new(state.sqlite.clone());
    let stats = gw.db_stats_counts().map_err(|_| {
        log_backdoor_operation("db_stats", "error", None);
        (
            StatusCode::INTERNAL_SERVER_ERROR,
            Json(json!({"success": false, "error": "internal"})),
        )
    })?;
    log_backdoor_operation("db_stats", "success", None);
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
    if !runtime_env::backdoor_db_clear_allowed() {
        log_backdoor_operation("db_clear", "blocked_production", None);
        return Ok(db_clear_denied_response());
    }
    let Some(token) = body.confirmation_token.as_deref().filter(|t| !t.is_empty()) else {
        log_backdoor_operation("db_clear", "missing_confirmation", None);
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
        log_backdoor_operation("db_clear", "invalid_confirmation", None);
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
    if let Some((status, ref body)) = presenter.response {
        if status == StatusCode::OK {
            log_backdoor_operation("db_clear", "success", None);
        } else {
            log_backdoor_operation("db_clear", "error", None);
        }
        return Ok((status, body.clone()));
    }
    log_backdoor_operation("db_clear", "error", None);
    Err((
        StatusCode::INTERNAL_SERVER_ERROR,
        Json(json!({"success": false, "error": "no response"})),
    ))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn create_user_requests_admin_grant_only_when_admin_true() {
        assert!(!create_user_requests_admin_grant(None));
        assert!(!create_user_requests_admin_grant(Some(false)));
        assert!(create_user_requests_admin_grant(Some(true)));
    }

    #[test]
    fn update_user_requests_admin_change_when_admin_field_present() {
        assert!(!update_user_requests_admin_change(None));
        assert!(update_user_requests_admin_change(Some(false)));
        assert!(update_user_requests_admin_change(Some(true)));
    }

    #[test]
    fn admin_change_denied_response_uses_production_error_key() {
        let (status, Json(body)) = admin_change_denied_response();
        assert_eq!(status, StatusCode::FORBIDDEN);
        assert_eq!(
            Some("api.errors.backdoor.admin_change_disabled_in_production"),
            body["error_key"].as_str()
        );
        assert_eq!(Some(false), body["success"].as_bool());
    }

    #[test]
    fn db_clear_denied_response_uses_production_error_key() {
        let (status, Json(body)) = db_clear_denied_response();
        assert_eq!(status, StatusCode::FORBIDDEN);
        assert_eq!(
            Some("api.errors.backdoor.db_clear_disabled_in_production"),
            body["error_key"].as_str()
        );
        assert_eq!(Some(false), body["success"].as_bool());
    }
}
