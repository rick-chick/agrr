//! OAuth / session routes (案 A — paths match OmniAuth).
//!
//! Ruby: `AuthController`, `config/initializers/omniauth.rb`

use crate::auth_return_to::{
    allowed_return_to, append_oauth_conversion_query, default_frontend_home,
    dev_environment_allowed, google_oauth_configured, OAUTH_RETURN_TO_COOKIE,
};
use crate::state::AppState;
use agrr_adapters_sqlite::{
    AuthOmniauthSessionSqliteGateway, GoogleOAuthUserInfo, OmniauthCallbackStatus,
    SessionLookupSqliteGateway,
};
use axum::{
    extract::{Query, State},
    http::{header, StatusCode},
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
        .route(
            "/auth/google_oauth2",
            get(start_google_oauth).post(start_google_oauth),
        )
        .route("/auth/google_oauth2/callback", get(google_callback))
        .route("/auth/failure", get(auth_failure))
        .route("/auth/logout", post(logout))
}

#[derive(Debug, Deserialize)]
struct LoginQuery {
    return_to: Option<String>,
}

async fn login_page(
    State(state): State<AppState>,
    Query(query): Query<LoginQuery>,
    jar: CookieJar,
) -> impl IntoResponse {
    let oauth_ready = google_oauth_configured(&state.google_client_id, &state.google_client_secret);
    let return_to = query.return_to.filter(|u| allowed_return_to(u));
    let jar = if let Some(ref url) = return_to {
        let mut cookie = Cookie::new(OAUTH_RETURN_TO_COOKIE, url.clone());
        cookie.set_http_only(true);
        cookie.set_same_site(SameSite::Lax);
        cookie.set_path("/");
        jar.add(cookie)
    } else {
        jar
    };

    let body = render_login_html(oauth_ready, return_to.as_deref());
    (jar, [(header::CONTENT_TYPE, "text/html; charset=utf-8")], body)
}

async fn start_google_oauth(
    State(state): State<AppState>,
    Query(query): Query<LoginQuery>,
    jar: CookieJar,
) -> Result<Response, StatusCode> {
    if !google_oauth_configured(&state.google_client_id, &state.google_client_secret) {
        tracing::warn!("Google OAuth not configured — redirecting to login page");
        let mut url = "/auth/login".to_string();
        if let Some(ref return_to) = query.return_to.filter(|u| allowed_return_to(u)) {
            url = format!(
                "/auth/login?return_to={}",
                url::form_urlencoded::byte_serialize(return_to.as_bytes()).collect::<String>()
            );
        }
        return Ok(Redirect::temporary(&url).into_response());
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
    let (auth_url, _csrf) = client
        .authorize_url(CsrfToken::new_random)
        .add_scope(Scope::new("openid".into()))
        .add_scope(Scope::new("email".into()))
        .add_scope(Scope::new("profile".into()))
        .url();
    Ok((jar, Redirect::temporary(auth_url.as_str())).into_response())
}

#[derive(Debug, Deserialize)]
struct OAuthCallbackQuery {
    code: Option<String>,
    error: Option<String>,
}

async fn google_callback(
    State(state): State<AppState>,
    Query(query): Query<OAuthCallbackQuery>,
    jar: CookieJar,
) -> Result<Response, StatusCode> {
    if query.error.is_some() || query.code.is_none() {
        return Ok(Redirect::to("/auth/failure").into_response());
    }
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
        return Ok(Redirect::to("/auth/failure").into_response());
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
    Redirect::to("/auth/login")
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
    (jar, Redirect::to("/auth/login"))
}

fn render_login_html(oauth_ready: bool, return_to: Option<&str>) -> String {
    let google_section = if oauth_ready {
        r#"<form method="get" action="/auth/google_oauth2">
            <button type="submit">Googleでサインイン</button>
           </form>"#
            .to_string()
    } else {
        r#"<div class="oauth-error">
            <p><strong>Google OAuth認証が設定されていません</strong></p>
            <p>ローカル開発では Angular ログイン画面の「開発用ログイン」を使うか、
               <code>GOOGLE_CLIENT_ID</code> / <code>GOOGLE_CLIENT_SECRET</code> を設定してください。</p>
           </div>"#
            .to_string()
    };

    let dev_section = if dev_environment_allowed() {
        let return_q = return_to
            .map(|u| format!(
                "?return_to={}",
                url::form_urlencoded::byte_serialize(u.as_bytes()).collect::<String>()
            ))
            .unwrap_or_default();
        format!(
            r#"<div class="dev-login">
              <h2>開発用ログイン</h2>
              <p><a href="/auth/test/mock_login_as/developer{return_q}">開発者としてログイン</a></p>
              <p><a href="/auth/test/mock_login_as/farmer{return_q}">農家としてログイン</a></p>
              <p><a href="/auth/test/mock_login_as/researcher{return_q}">研究者としてログイン</a></p>
              <p><a href="{frontend}">Angular ログイン画面に戻る</a></p>
            </div>"#,
            frontend = default_frontend_home().trim_end_matches('/'),
        )
    } else {
        String::new()
    };

    format!(
        r#"<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><title>AGRR Login</title></head>
        <body>
        <h1>AGRR Login</h1>
        {google_section}
        {dev_section}
        </body></html>"#
    )
}

fn google_oauth_client(state: &AppState) -> Result<BasicClient, StatusCode> {
    let redirect = std::env::var("GOOGLE_OAUTH_REDIRECT_URI").unwrap_or_else(|_| {
        "http://localhost:3000/auth/google_oauth2/callback".to_string()
    });
    Ok(BasicClient::new(
        ClientId::new(state.google_client_id.to_string()),
        Some(ClientSecret::new(state.google_client_secret.to_string())),
        AuthUrl::new("https://accounts.google.com/o/oauth2/v2/auth".into()).unwrap(),
        Some(TokenUrl::new("https://oauth2.googleapis.com/token".into()).unwrap()),
    )
    .set_redirect_uri(RedirectUrl::new(redirect).map_err(|_| StatusCode::INTERNAL_SERVER_ERROR)?))
}
