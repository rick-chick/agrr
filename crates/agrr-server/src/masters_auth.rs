//! Masters API authentication (API key or session cookie) — Rails `BaseController` parity.

use crate::state::AppState;
use agrr_adapters_sqlite::{ApiKeyPrincipalSqliteGateway, SessionCookiePrincipalSqliteGateway};
use agrr_domain::shared::dtos::{
    masters_api_scope_allows, MastersApiAccessRequirement, MastersApiCredentialsResolveInput,
    SessionPrincipal,
};
use agrr_domain::shared::interactors::MastersApiCredentialsResolveInteractor;
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

pub fn extract_api_key(headers: &HeaderMap, _query: Option<&str>) -> Option<String> {
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
    None
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
    if port.denied {
        return Err(StatusCode::UNAUTHORIZED);
    }
    port.principal.ok_or(StatusCode::UNAUTHORIZED)
}

pub fn resolve_masters_user_id(
    state: &AppState,
    jar: &CookieJar,
    headers: &HeaderMap,
    query_api_key: Option<&str>,
) -> Result<i64, StatusCode> {
    resolve_masters_principal(state, jar, headers, query_api_key).map(|p| p.id)
}

fn scope_denied() -> (StatusCode, axum::Json<serde_json::Value>) {
    (
        StatusCode::FORBIDDEN,
        axum::Json(serde_json::json!({"error": "forbidden", "error_code": "insufficient_scope"})),
    )
}

fn unauthorized() -> (StatusCode, axum::Json<serde_json::Value>) {
    (
        StatusCode::UNAUTHORIZED,
        axum::Json(serde_json::json!({"error": "unauthorized"})),
    )
}

fn enforce_api_key_scopes(
    principal: &SessionPrincipal,
    method: &Method,
    path: &str,
    query: Option<&str>,
) -> Result<(), (StatusCode, axum::Json<serde_json::Value>)> {
    let Some(scopes) = principal.api_key_scopes.as_ref() else {
        return Ok(());
    };
    let Some(requirement) =
        MastersApiAccessRequirement::from_http(method.as_str(), path, query)
    else {
        return Ok(());
    };
    if masters_api_scope_allows(scopes, requirement) {
        Ok(())
    } else {
        Err(scope_denied())
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
        let principal = resolve_masters_principal(&app_state, &jar, &parts.headers, None)
            .map_err(|_| unauthorized())?;
        enforce_api_key_scopes(
            &principal,
            &parts.method,
            parts.uri.path(),
            parts.uri.query(),
        )?;
        Ok(MastersUserId(principal.id))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn enforce_api_key_scopes_allows_session_principal() {
        let principal = SessionPrincipal {
            id: 1,
            email: String::new(),
            name: String::new(),
            admin: false,
            anonymous: false,
            api_key_scopes: None,
        };
        assert!(enforce_api_key_scopes(
            &principal,
            &Method::POST,
            "/api/v1/masters/crops",
            None
        )
        .is_ok());
    }

    #[test]
    fn extract_api_key_ignores_query_parameter() {
        let headers = HeaderMap::new();
        assert!(extract_api_key(&headers, Some("secret-key")).is_none());
    }

    #[test]
    fn enforce_api_key_scopes_denies_write_without_write_scope() {
        let principal = SessionPrincipal {
            id: 1,
            email: String::new(),
            name: String::new(),
            admin: false,
            anonymous: false,
            api_key_scopes: Some(vec!["masters:read".into()]),
        };
        assert!(enforce_api_key_scopes(
            &principal,
            &Method::GET,
            "/api/v1/masters/crops",
            None
        )
        .is_ok());
        assert!(enforce_api_key_scopes(
            &principal,
            &Method::POST,
            "/api/v1/masters/crops",
            None
        )
        .is_err());
    }
}
