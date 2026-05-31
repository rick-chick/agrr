//! Masters API authentication (API key or session cookie) — Rails `BaseController` parity.

use crate::state::AppState;
use agrr_adapters_sqlite::{ApiKeyPrincipalSqliteGateway, SessionCookiePrincipalSqliteGateway};
use agrr_domain::shared::dtos::{MastersApiCredentialsResolveInput, SessionPrincipal};
use agrr_domain::shared::interactors::MastersApiCredentialsResolveInteractor;
use agrr_domain::shared::ports::MastersApiCredentialsResolveOutputPort;
use axum::{
    extract::{FromRef, FromRequestParts},
    http::{request::Parts, HeaderMap, StatusCode},
};
use axum_extra::extract::cookie::CookieJar;

/// Resolved masters API user id (non-anonymous).
#[derive(Clone, Copy)]
pub struct MastersUserId(pub i64);

struct ResolvePort {
    user_id: Option<i64>,
    denied: bool,
}

impl MastersApiCredentialsResolveOutputPort for ResolvePort {
    fn on_success(&mut self, principal: SessionPrincipal) {
        if principal.authenticated() {
            self.user_id = Some(principal.id);
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
    let session_id = jar.get("session_id").map(|c| c.value().to_string());
    let input = MastersApiCredentialsResolveInput::new(extract_api_key(headers, query_api_key), session_id);
    let api_gw = ApiKeyPrincipalSqliteGateway::new(state.sqlite.clone());
    let session_gw = SessionCookiePrincipalSqliteGateway::new(state.sqlite.clone());
    let mut port = ResolvePort {
        user_id: None,
        denied: false,
    };
    let mut interactor =
        MastersApiCredentialsResolveInteractor::new(&mut port, &api_gw, &session_gw);
    interactor.call(&input);
    port.user_id.ok_or(StatusCode::UNAUTHORIZED)
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
        let user_id = resolve_masters_user_id(&app_state, &jar, &parts.headers, query_key)
            .map_err(|_| unauthorized())?;
        Ok(MastersUserId(user_id))
    }
}

fn unauthorized() -> (StatusCode, axum::Json<serde_json::Value>) {
    (
        StatusCode::UNAUTHORIZED,
        axum::Json(serde_json::json!({"error": "unauthorized"})),
    )
}
