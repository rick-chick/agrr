//! Development/test mock login (`GET /auth/test/developer`).

use crate::adapters::PassthroughTranslator;
use crate::auth_return_to::{
    allowed_return_to, default_frontend_home, dev_environment_allowed, normalize_oauth_return_to,
};
use crate::state::AppState;
use agrr_adapters_sqlite::AuthTestLoginSqliteGateway;
use agrr_domain::auth::dtos::AuthTestMockLoginInput;
use agrr_domain::auth::interactors::AuthTestMockLoginInteractor;
use agrr_domain::auth::ports::{AuthTestMockLoginOutputPort, OauthConversionUrlAppenderPort};
use axum::{
    extract::{Query, State},
    http::{header, StatusCode},
    response::{IntoResponse, Redirect, Response},
    routing::get,
    Router,
};
use axum_extra::extract::cookie::{Cookie, CookieJar, SameSite};
use serde::Deserialize;

/// Rails: `GET /auth/test/mock_login_as/developer` (Playwright `E2E_CAPTURE_DEV_SESSION`).
pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/auth/test/developer", get(developer_login))
        .route("/auth/test/mock_login", get(developer_login))
        .route("/auth/test/mock_login_as/{user}", get(mock_login_as))
}

#[derive(Debug, Deserialize)]
struct DevLoginQuery {
    return_to: Option<String>,
}

async fn developer_login(
    State(state): State<AppState>,
    Query(query): Query<DevLoginQuery>,
    jar: CookieJar,
) -> Result<Response, StatusCode> {
    mock_login_impl(
        state,
        query.return_to,
        "dev_user_001",
        "developer@agrr.dev",
        "開発者",
        "dev-avatar.svg",
        true,
        jar,
    )
    .await
}

async fn mock_login_as(
    State(state): State<AppState>,
    axum::extract::Path(user): axum::extract::Path<String>,
    Query(query): Query<DevLoginQuery>,
    jar: CookieJar,
) -> Result<Response, StatusCode> {
    let (google_id, email, name, admin) = match user.as_str() {
        "developer" => ("dev_user_001", "developer@agrr.dev", "開発者", true),
        "farmer" => ("farmer_user_001", "farmer@agrr.dev", "農家", false),
        "researcher" => ("researcher_user_001", "researcher@agrr.dev", "研究者", false),
        "contract_api" => (
            "contract_api_user_001",
            "contract-api@agrr.dev",
            "Contract API",
            false,
        ),
        "e2e_empty" => (
            "e2e_empty_user_001",
            "e2e-empty@agrr.dev",
            "E2E Empty",
            false,
        ),
        _ => return Ok(Redirect::to("/").into_response()),
    };
    mock_login_impl(
        state,
        query.return_to,
        google_id,
        email,
        name,
        "",
        admin,
        jar,
    )
    .await
}

struct HtmlPresenter {
    redirect: Option<String>,
    cookie: Option<(String, time::OffsetDateTime)>,
    alert: Option<String>,
}

impl AuthTestMockLoginOutputPort for HtmlPresenter {
    fn on_environment_forbidden(&mut self) {
        self.alert = Some("auth_test.env_only".into());
    }

    fn on_missing_mock(&mut self) {
        self.alert = Some("auth_test.mock_data_missing".into());
    }

    fn on_create_failed(&mut self, _error_messages: Vec<String>) {
        self.alert = Some("auth_test.mock_data_missing".into());
    }

    fn on_success_process_saved_plan(&mut self, session_id: &str, expires_at: time::OffsetDateTime) {
        self.cookie = Some((session_id.to_string(), expires_at));
    }

    fn on_success_return_to(
        &mut self,
        url: &str,
        session_id: &str,
        expires_at: time::OffsetDateTime,
        _user_name: &str,
    ) {
        self.redirect = Some(url.to_string());
        self.cookie = Some((session_id.to_string(), expires_at));
    }

    fn on_success_root(
        &mut self,
        session_id: &str,
        expires_at: time::OffsetDateTime,
        _user_name: &str,
    ) {
        self.cookie = Some((session_id.to_string(), expires_at));
    }
}

struct NoopAppender;

impl OauthConversionUrlAppenderPort for NoopAppender {
    fn append(&self, url: &str) -> String {
        url.to_string()
    }
}

async fn mock_login_impl(
    state: AppState,
    return_to: Option<String>,
    google_id: &str,
    email: &str,
    name: &str,
    avatar: &str,
    grant_admin: bool,
    jar: CookieJar,
) -> Result<Response, StatusCode> {
    if !dev_environment_allowed() {
        return Ok((
            StatusCode::FORBIDDEN,
            [(header::CONTENT_TYPE, "text/html; charset=utf-8")],
            "<html><body><p>Mock login is only available when AGRR_ENV is development or test (or ENABLE_MOCK_AUTH=1 in non-production).</p></body></html>",
        )
            .into_response());
    }

    let pending_allowed = return_to
        .as_deref()
        .map(allowed_return_to)
        .unwrap_or(false);
    let input = AuthTestMockLoginInput::new(
        google_id,
        email,
        name,
        avatar,
        grant_admin,
        false,
        return_to.clone(),
        pending_allowed,
    );

    let gateway = AuthTestLoginSqliteGateway::new(state.sqlite.clone());
    let appender = NoopAppender;
    let _translator = PassthroughTranslator;
    let mut presenter = HtmlPresenter {
        redirect: None,
        cookie: None,
        alert: None,
    };

    let mut interactor =
        AuthTestMockLoginInteractor::new(&mut presenter, &gateway, &appender);
    interactor.call(&input, true);

    if let Some((session_id, expires)) = presenter.cookie {
        let mut cookie = Cookie::new("session_id", session_id);
        cookie.set_http_only(true);
        cookie.set_same_site(SameSite::Lax);
        cookie.set_path("/");
        cookie.set_expires(expires);
        let jar = jar.add(cookie);
        if let Some(url) = presenter.redirect {
            let url = normalize_oauth_return_to(&url);
            return Ok((jar, Redirect::temporary(&url)).into_response());
        }
        return Ok((jar, Redirect::temporary(&default_frontend_home())).into_response());
    }

    let body = presenter
        .alert
        .unwrap_or_else(|| "login failed".into());
    Ok((
        [(header::CONTENT_TYPE, "text/html; charset=utf-8")],
        format!("<html><body><p>{body}</p></body></html>"),
    )
        .into_response())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_support::test_app_state;
    use crate::test_support::test_pool_with_plan;
    use axum::body::Body;
    use axum::http::{Request, StatusCode};
    use tower::util::ServiceExt;

    #[test]
    fn mock_login_returns_forbidden_in_production_without_enable_mock_auth() {
        let prev_env = std::env::var("AGRR_ENV").ok();
        let prev_rails = std::env::var("RAILS_ENV").ok();
        let prev_mock = std::env::var("ENABLE_MOCK_AUTH").ok();

        std::env::set_var("AGRR_ENV", "production");
        std::env::remove_var("RAILS_ENV");
        std::env::remove_var("ENABLE_MOCK_AUTH");

        let rt = tokio::runtime::Runtime::new().expect("tokio runtime");
        let state = test_app_state(test_pool_with_plan(1).pool);
        let app = routes().with_state(state);
        let response = rt.block_on(async {
            app.oneshot(
                Request::builder()
                    .uri("/auth/test/developer")
                    .body(Body::empty())
                    .expect("request"),
            )
            .await
            .expect("response")
        });

        assert_eq!(StatusCode::FORBIDDEN, response.status());

        restore_test_env("AGRR_ENV", prev_env);
        restore_test_env("RAILS_ENV", prev_rails);
        restore_test_env("ENABLE_MOCK_AUTH", prev_mock);
    }

    fn restore_test_env(key: &str, value: Option<String>) {
        match value {
            Some(v) => std::env::set_var(key, v),
            None => std::env::remove_var(key),
        }
    }
}
