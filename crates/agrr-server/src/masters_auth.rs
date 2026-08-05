//! Masters API authentication (API key or session cookie) — Rails `BaseController` parity.

use crate::state::AppState;
use agrr_adapters_sqlite::{ApiKeyPrincipalSqliteGateway, SessionCookiePrincipalSqliteGateway};
use agrr_domain::shared::dtos::{MastersApiCredentialsResolveInput, SessionPrincipal};
use agrr_domain::shared::interactors::MastersApiCredentialsResolveInteractor;
use agrr_domain::shared::policies::masters_api_scope_policy::{MastersApiAccess, MastersApiScopePolicy};
use agrr_domain::shared::ports::MastersApiCredentialsResolveOutputPort;
use axum::{
    extract::{FromRef, FromRequestParts},
    http::{request::Parts, HeaderMap, Method, StatusCode},
};
use axum_extra::extract::cookie::CookieJar;

/// Resolved masters API user id (non-anonymous).
#[derive(Clone, Copy)]
pub struct MastersUserId(pub i64);

struct ResolvePort {
    principal: Option<SessionPrincipal>,
    denied: bool,
}

impl MastersApiCredentialsResolveOutputPort for ResolvePort {
    fn on_success(&mut self, principal: SessionPrincipal) {
        if principal.authenticated() {
            self.principal = Some(principal);
        } else {
            self.denied = true;
        }
    }

    fn on_invalid_api_key(&mut self) {
        self.denied = true;
    }

    fn on_login_required(&mut self) {
        self.denied = true;
    }
}

pub fn extract_api_key(headers: &HeaderMap, query: Option<&str>) -> Option<String> {
    if let Some(auth) = headers.get("authorization").and_then(|v| v.to_str().ok()) {
        let auth = auth.trim();
        if let Some(rest) = auth.strip_prefix("Bearer ") {
            let key = rest.trim();
            if !key.is_empty() {
                return Some(key.to_string());
            }
        }
    }
    if let Some(key) = headers.get("x-api-key").and_then(|v| v.to_str().ok()) {
        let key = key.trim();
        if !key.is_empty() {
            return Some(key.to_string());
        }
    }
    if let Some(key) = query {
        let key = key.trim();
        if !key.is_empty() {
            return Some(key.to_string());
        }
    }
    None
}

pub fn resolve_masters_user_id(
    state: &AppState,
    jar: &CookieJar,
    headers: &HeaderMap,
    query_api_key: Option<&str>,
) -> Result<i64, StatusCode> {
    let principal = resolve_masters_principal(state, jar, headers, query_api_key)?;
    Ok(principal.id)
}

pub fn resolve_masters_principal(
    state: &AppState,
    jar: &CookieJar,
    headers: &HeaderMap,
    query_api_key: Option<&str>,
) -> Result<SessionPrincipal, StatusCode> {
    let session_id = jar.get("session_id").map(|c| c.value().to_string());
    let input = MastersApiCredentialsResolveInput::new(extract_api_key(headers, query_api_key), session_id);
    let api_gw = ApiKeyPrincipalSqliteGateway::new(state.sqlite.clone());
    let session_gw = SessionCookiePrincipalSqliteGateway::new(state.sqlite.clone());
    let mut port = ResolvePort {
        principal: None,
        denied: false,
    };
    let mut interactor =
        MastersApiCredentialsResolveInteractor::new(&mut port, &api_gw, &session_gw);
    interactor.call(&input);
    port.principal.ok_or(StatusCode::UNAUTHORIZED)
}

fn required_masters_access(parts: &Parts) -> MastersApiAccess {
    match parts.method {
        Method::GET | Method::HEAD => MastersApiAccess::Read,
        Method::POST | Method::PUT | Method::PATCH | Method::DELETE => {
            if parts.uri.path().ends_with("/setup_proposal") {
                let mode = parts
                    .uri
                    .query()
                    .and_then(|q| {
                        q.split('&').find_map(|pair| {
                            let (k, v) = pair.split_once('=')?;
                            if k == "mode" {
                                Some(v)
                            } else {
                                None
                            }
                        })
                    })
                    .unwrap_or("");
                if mode == "apply" {
                    MastersApiAccess::SetupProposalApply
                } else {
                    MastersApiAccess::SetupProposalDryRun
                }
            } else {
                MastersApiAccess::Write
            }
        }
        _ => MastersApiAccess::Read,
    }
}

impl<S> FromRequestParts<S> for MastersUserId
where
    S: Send + Sync,
    AppState: axum::extract::FromRef<S>,
{
    type Rejection = (StatusCode, axum::Json<serde_json::Value>);

    async fn from_request_parts(parts: &mut Parts, state: &S) -> Result<Self, Self::Rejection> {
        let app_state = AppState::from_ref(state);
        let jar = CookieJar::from_request_parts(parts, state)
            .await
            .map_err(|_| unauthorized())?;
        let query_key = parts
            .uri
            .query()
            .and_then(|q| {
                q.split('&').find_map(|pair| {
                    let (k, v) = pair.split_once('=')?;
                    if k == "api_key" {
                        Some(v)
                    } else {
                        None
                    }
                })
            });
        let principal = resolve_masters_principal(&app_state, &jar, &parts.headers, query_key)
            .map_err(|_| unauthorized())?;
        let access = required_masters_access(parts);
        if !MastersApiScopePolicy::allows(&principal, access) {
            return Err(forbidden());
        }
        Ok(MastersUserId(principal.id))
    }
}

fn unauthorized() -> (StatusCode, axum::Json<serde_json::Value>) {
    (
        StatusCode::UNAUTHORIZED,
        axum::Json(serde_json::json!({"error": "unauthorized"})),
    )
}

fn forbidden() -> (StatusCode, axum::Json<serde_json::Value>) {
    (
        StatusCode::FORBIDDEN,
        axum::Json(serde_json::json!({"error": "forbidden", "error_code": "insufficient_scope"})),
    )
}
