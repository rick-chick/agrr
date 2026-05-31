//! OAuth / session routes (案 A — paths match OmniAuth).
//!
//! Ruby: `AuthController`, `config/initializers/omniauth.rb`

use crate::auth_return_to::{
    allowed_return_to, append_oauth_conversion_query, default_frontend_home,
    google_oauth_configured, oauth_csrf_state_matches, spa_login_redirect_url,
    OAUTH_CSRF_STATE_COOKIE, OAUTH_RETURN_TO_COOKIE,
};
use crate::state::AppState;
use agrr_adapters_sqlite::{
    AuthOmniauthSessionSqliteGateway, GoogleOAuthUserInfo, OmniauthCallbackStatus,
    SessionLookupSqliteGateway,
};
use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::{IntoResponse, Redirect, Response},
    routing::{get, post},
    Router,
};
use axum_extra::extract::cookie::{Cookie, CookieJar, SameSite};
use oauth2::{
    basic::BasicClient, AuthUrl, AuthorizationCode, ClientId, ClientSecret, CsrfToken,
    RedirectUrl, Scope, TokenResponse, TokenUrl,
};
use serde::Deserialize;
use agrr_domain::auth::gateways::UserSessionRevocationGateway;

pub fn routes() -> Router<AppState> {
    Router::new()
        .route("/auth/login", get(login_page))
        .route("/{locale}/auth/login", get(login_page))
        .route("/auth/google_oauth2", post(start_google_oauth))
        .route("/auth/google_oauth2/callback", get(google_callback))
        .route("/auth/failure", get(auth_failure))
        .route("/auth/logout", post(logout))
}

#[derive(Debug, Deserialize)]
struct LoginQuery {
    return_to: Option<String>,
}

async fn login_page(Query(query): Query<LoginQuery>) -> Redirect {
    Redirect::temporary(&spa_login_redirect_url(query.return_to.as_deref()))
}

async fn start_google_oauth(
    State(state): State<AppState>,
    Query(query): Query<LoginQuery>,
    jar: CookieJar,
) -> Result<Response, StatusCode> {
    if !google_oauth_configured(&state.google_client_id, &state.google_client_secret) {
        tracing::warn!("Google OAuth not configured — redirecting to SPA login");
        return Ok(Redirect::temporary(&spa_login_redirect_url(query.return_to.as_deref())).into_response());
    }

    let jar = if let Some(ref url) = query.return_to.filter(|u| allowed_return_to(u)) {
        let mut cookie = Cookie::new(OAUTH_RETURN_TO_COOKIE, url.clone());
        cookie.set_http_only(true);
        cookie.set_same_site(SameSite::Lax);
        cookie.set_path("/");
        jar.add(cookie)
    } else {
        jar
    };

    let client = google_oauth_client(&state)?;
    let (auth_url, csrf) = client
        .authorize_url(CsrfToken::new_random)
        .add_scope(Scope::new("openid".into()))
        .add_scope(Scope::new("email".into()))
        .add_scope(Scope::new("profile".into()))
        .url();
    let jar = jar_with_oauth_csrf(jar, csrf.secret());
    Ok((jar, Redirect::temporary(auth_url.as_str())).into_response())
}

#[derive(Debug, Deserialize)]
struct OAuthCallbackQuery {
    code: Option<String>,
    error: Option<String>,
    state: Option<String>,
}

async fn google_callback(
    State(state): State<AppState>,
    Query(query): Query<OAuthCallbackQuery>,
    jar: CookieJar,
) -> Result<Response, StatusCode> {
    if query.error.is_some() || query.code.is_none() {
        return Ok(Redirect::temporary(&spa_login_redirect_url(None)).into_response());
    }
    let stored_csrf = jar
        .get(OAUTH_CSRF_STATE_COOKIE)
        .map(|c| c.value().to_string());
    if !oauth_csrf_state_matches(stored_csrf.as_deref(), query.state.as_deref()) {
        tracing::warn!("OAuth callback rejected: CSRF state mismatch");
        return Ok(Redirect::temporary(&spa_login_redirect_url(None)).into_response());
    }
    let jar = jar.remove(Cookie::from(OAUTH_CSRF_STATE_COOKIE));
    let client = google_oauth_client(&state)?;
    let token = client
        .exchange_code(AuthorizationCode::new(query.code.unwrap()))
        .request_async(oauth2::reqwest::async_http_client)
        .await
        .map_err(|_| StatusCode::BAD_GATEWAY)?;

    let userinfo: serde_json::Value = reqwest::Client::new()
        .get("https://www.googleapis.com/oauth2/v2/userinfo")
        .bearer_auth(token.access_token().secret())
        .send()
        .await
        .map_err(|_| StatusCode::BAD_GATEWAY)?
        .json()
        .await
        .map_err(|_| StatusCode::BAD_GATEWAY)?;

    let info = GoogleOAuthUserInfo {
        google_id: userinfo["id"].as_str().unwrap_or("").to_string(),
        email: userinfo["email"].as_str().unwrap_or("").to_string(),
        name: userinfo["name"].as_str().unwrap_or("").to_string(),
        avatar_url: userinfo["picture"].as_str().map(|s| s.to_string()),
    };

    let gateway = AuthOmniauthSessionSqliteGateway::new(state.sqlite.clone());
    let result = gateway.process_google_callback(&info);
    if result.status != OmniauthCallbackStatus::Success {
        return Ok(Redirect::temporary(&spa_login_redirect_url(None)).into_response());
    }

    let mut cookie = Cookie::new("session_id", result.session_id.unwrap_or_default());
    cookie.set_http_only(true);
    cookie.set_same_site(SameSite::Lax);
    cookie.set_path("/");
    if state.secure_cookies {
        cookie.set_secure(true);
    }
    if let Some(expires) = result.expires_at_rfc3339 {
        if let Ok(time) = time::OffsetDateTime::parse(
            &expires,
            &time::format_description::well_known::Iso8601::DEFAULT,
        ) {
            cookie.set_expires(time);
        }
    }

    let redirect_target = jar
        .get(OAUTH_RETURN_TO_COOKIE)
        .map(|c| c.value().to_string())
        .filter(|u| allowed_return_to(u))
        .map(|u| append_oauth_conversion_query(&u))
        .unwrap_or_else(default_frontend_home);

    let jar = jar
        .add(cookie)
        .remove(Cookie::from(OAUTH_RETURN_TO_COOKIE));
    Ok((jar, Redirect::temporary(&redirect_target)).into_response())
}

async fn auth_failure() -> Redirect {
    Redirect::temporary(&spa_login_redirect_url(None))
}

async fn logout(State(state): State<AppState>, jar: CookieJar) -> impl IntoResponse {
    if let Some(session_cookie) = jar.get("session_id") {
        if let Ok(Some(record)) = SessionLookupSqliteGateway::new(state.sqlite.clone())
            .find_active_by_session_id(session_cookie.value())
        {
            agrr_adapters_sqlite::UserSessionRevocationSqliteGateway::new(state.sqlite.clone())
                .delete_all_sessions_for_user(record.user_id);
        }
    }
    let jar = jar.remove(Cookie::from("session_id"));
    (jar, Redirect::temporary(&spa_login_redirect_url(None)))
}

fn jar_with_oauth_csrf(jar: CookieJar, csrf_secret: &str) -> CookieJar {
    let mut cookie = Cookie::new(OAUTH_CSRF_STATE_COOKIE, csrf_secret.to_string());
    cookie.set_http_only(true);
    cookie.set_same_site(SameSite::Lax);
    cookie.set_path("/");
    jar.add(cookie)
}

fn google_oauth_client(state: &AppState) -> Result<BasicClient, StatusCode> {
    let redirect = crate::auth_return_to::google_oauth_redirect_uri();
    Ok(BasicClient::new(
        ClientId::new(state.google_client_id.to_string()),
        Some(ClientSecret::new(state.google_client_secret.to_string())),
        AuthUrl::new("https://accounts.google.com/o/oauth2/v2/auth".into()).unwrap(),
        Some(TokenUrl::new("https://oauth2.googleapis.com/token".into()).unwrap()),
    )
    .set_redirect_uri(RedirectUrl::new(redirect).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?))
}
