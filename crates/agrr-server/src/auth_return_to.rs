//! Shared OAuth return_to validation (Rails `AuthController#allowed_return_to?` parity).

pub const OAUTH_RETURN_TO_COOKIE: &str = "oauth_return_to";
pub const OAUTH_CSRF_STATE_COOKIE: &str = "oauth_csrf_state";

/// Google コールバックの `state` と開始時 Cookie の一致（OAuth CSRF 対策）。
pub fn oauth_csrf_state_matches(stored: Option<&str>, returned: Option<&str>) -> bool {
    match (stored, returned) {
        (Some(a), Some(b)) if !a.is_empty() && a == b => true,
        _ => false,
    }
}

/// Rails development.rb placeholder — treat as "not configured".
const PLACEHOLDER_CLIENT_ID: &str = "your_google_client_id_here";
const PLACEHOLDER_CLIENT_SECRET: &str = "your_google_client_secret_here";

pub fn google_oauth_configured(client_id: &str, client_secret: &str) -> bool {
    if client_id.is_empty() || client_secret.is_empty() {
        return false;
    }
    client_id != PLACEHOLDER_CLIENT_ID && client_secret != PLACEHOLDER_CLIENT_SECRET
}

pub fn dev_environment_allowed() -> bool {
    crate::runtime_env::dev_environment_allowed()
}

/// Google OAuth redirect URI (案 A). `GOOGLE_OAUTH_REDIRECT_URI` があれば優先、なければ `FRONTEND_URL` 先頭 origin。
pub fn google_oauth_redirect_uri() -> String {
    if let Ok(explicit) = std::env::var("GOOGLE_OAUTH_REDIRECT_URI") {
        let trimmed = explicit.trim();
        if !trimmed.is_empty() {
            return trimmed.to_string();
        }
    }
    let origin = frontend_origins()
        .into_iter()
        .next()
        .unwrap_or_else(|| build_origin(&url::Url::parse("http://127.0.0.1:4200").unwrap()));
    format!("{origin}/auth/google_oauth2/callback")
}

/// Angular `/login` へリダイレクト（Rust HTML ログイン画面は使わない）。
pub fn spa_login_redirect_url(return_to: Option<&str>) -> String {
    let home = default_frontend_home();
    let base = home.trim_end_matches('/');
    match return_to.filter(|u| allowed_return_to(u)) {
        Some(rt) => format!(
            "{base}/login?return_to={}",
            url::form_urlencoded::byte_serialize(rt.as_bytes()).collect::<String>()
        ),
        None => format!("{base}/login"),
    }
}

/// First `FRONTEND_URL` entry + `/` — avoid redirecting to nginx `location /` (404) on :3000.
pub fn default_frontend_home() -> String {
    let frontend_urls = std::env::var("FRONTEND_URL")
        .unwrap_or_else(|_| "http://127.0.0.1:4200,http://localhost:4200".into());
    let origin = frontend_urls
        .split(',')
        .map(str::trim)
        .find(|s| !s.is_empty())
        .unwrap_or("http://127.0.0.1:4200");
    if origin.ends_with('/') {
        origin.to_string()
    } else {
        format!("{origin}/")
    }
}

/// Matches Rails `AuthController#build_origin`.
pub fn build_origin(uri: &url::Url) -> String {
    let host = uri.host_str().unwrap_or("localhost");
    let default_port = match uri.scheme() {
        "http" => Some(80),
        "https" => Some(443),
        _ => None,
    };
    match uri.port() {
        Some(port) if Some(port) != default_port => {
            format!("{}://{host}:{port}", uri.scheme())
        }
        _ => format!("{}://{host}", uri.scheme()),
    }
}

fn host_matches_allowed_hosts(host: &str) -> bool {
    let allowed = std::env::var("ALLOWED_HOSTS").unwrap_or_default();
    allowed
        .split(',')
        .map(str::trim)
        .filter(|s| !s.is_empty())
        .any(|pattern| host_matches_pattern(host, pattern))
}

fn host_matches_pattern(host: &str, pattern: &str) -> bool {
    let pattern = pattern.trim();
    if pattern.is_empty() {
        return false;
    }
    if let Some(suffix) = pattern.strip_prefix('.') {
        host.eq_ignore_ascii_case(suffix) || host.to_ascii_lowercase().ends_with(&format!(".{suffix}"))
    } else {
        host.eq_ignore_ascii_case(pattern)
    }
}

pub fn allowed_return_to(url: &str) -> bool {
    let Ok(uri) = url::Url::parse(url) else {
        return false;
    };
    if uri.scheme() != "http" && uri.scheme() != "https" {
        return false;
    }
    let origin = build_origin(&uri);
    if frontend_origins().contains(&origin) {
        return true;
    }
    uri.host_str()
        .is_some_and(host_matches_allowed_hosts)
}

fn frontend_origins() -> Vec<String> {
    std::env::var("FRONTEND_URL")
        .unwrap_or_else(|_| "http://127.0.0.1:4200,http://localhost:4200".into())
        .split(',')
        .map(|s| s.trim().to_string())
        .filter(|s| !s.is_empty())
        .filter_map(|base| url::Url::parse(&base).ok())
        .map(|u| build_origin(&u))
        .collect()
}

/// Rails `OauthConversionUrlAppender` — append `?_agrr_oauth=1` for ad conversion tracking.
pub fn append_oauth_conversion_query(url: &str) -> String {
    let Ok(mut uri) = url::Url::parse(url) else {
        return url.to_string();
    };
    if uri.scheme() != "http" && uri.scheme() != "https" {
        return url.to_string();
    }
    let mut pairs: Vec<(String, String)> = uri
        .query_pairs()
        .map(|(k, v)| (k.into_owned(), v.into_owned()))
        .collect();
    if !pairs.iter().any(|(k, _)| k == "_agrr_oauth") {
        pairs.push(("_agrr_oauth".into(), "1".into()));
    }
    let query: String = pairs
        .iter()
        .map(|(k, v)| format!("{}={}", urlencoding_encode(k), urlencoding_encode(v)))
        .collect::<Vec<_>>()
        .join("&");
    uri.set_query(Some(&query));
    uri.to_string()
}

fn urlencoding_encode(s: &str) -> String {
    url::form_urlencoded::byte_serialize(s.as_bytes()).collect()
}

/// Query param for client-side navigation after OAuth lands on `/` (parity: frontend `POST_LOGIN_QUERY_PARAM`).
pub const POST_LOGIN_QUERY_PARAM: &str = "_post_login";

/// Paths that require login — must not be OAuth full-page landing targets (no GCS SPA shell).
/// Keep in sync with `AUTH_REQUIRED_PREFIXES` in `frontend/.../login-auth-urls.ts`.
const AUTH_REQUIRED_PREFIXES: &[&str] = &[
    "/plans",
    "/farms",
    "/crops",
    "/fertilizes",
    "/pests",
    "/pesticides",
    "/agricultural_tasks",
    "/interaction_rules",
    "/dashboard",
    "/api-keys",
];

fn requires_auth_direct_landing(path: &str) -> bool {
    let path = path.trim_end_matches('/');
    if path.is_empty() || path == "/" {
        return false;
    }
    AUTH_REQUIRED_PREFIXES
        .iter()
        .any(|prefix| path == *prefix || path.starts_with(&format!("{prefix}/")))
}

/// Auth-required `return_to` → `origin/?_post_login=<path+query>` for client-side navigation after `/` loads.
pub fn normalize_oauth_return_to(url: &str) -> String {
    let Ok(uri) = url::Url::parse(url) else {
        return url.to_string();
    };
    if !requires_auth_direct_landing(uri.path()) {
        return url.to_string();
    }
    let path = uri.path();
    let path_and_search = match uri.query() {
        Some(q) => format!("{path}?{q}"),
        None => path.to_string(),
    };
    let origin = build_origin(&uri);
    format!(
        "{origin}/?{POST_LOGIN_QUERY_PARAM}={}",
        urlencoding_encode(&path_and_search)
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Mutex;

    static ENV_TEST_LOCK: Mutex<()> = Mutex::new(());

    fn env_test_lock() -> std::sync::MutexGuard<'static, ()> {
        ENV_TEST_LOCK
            .lock()
            .unwrap_or_else(std::sync::PoisonError::into_inner)
    }

    #[test]
    fn google_oauth_configured_rejects_empty_and_placeholders() {
        assert!(!google_oauth_configured("", "secret"));
        assert!(!google_oauth_configured("id", ""));
        assert!(!google_oauth_configured(
            PLACEHOLDER_CLIENT_ID,
            "real_secret"
        ));
        assert!(!google_oauth_configured(
            "real_id",
            PLACEHOLDER_CLIENT_SECRET
        ));
        assert!(google_oauth_configured("real_id", "real_secret"));
    }

    #[test]
    fn build_origin_includes_non_default_port() {
        let uri = url::Url::parse("http://127.0.0.1:4200/").unwrap();
        assert_eq!(build_origin(&uri), "http://127.0.0.1:4200");
    }

    #[test]
    fn spa_login_redirect_url_includes_return_to_when_allowed() {
        let _guard = env_test_lock();
        std::env::set_var("FRONTEND_URL", "http://127.0.0.1:4200");
        assert_eq!(
            spa_login_redirect_url(Some("http://127.0.0.1:4200/plans")),
            "http://127.0.0.1:4200/login?return_to=http%3A%2F%2F127.0.0.1%3A4200%2Fplans"
        );
        assert_eq!(spa_login_redirect_url(None), "http://127.0.0.1:4200/login");
        std::env::remove_var("FRONTEND_URL");
    }

    #[test]
    fn oauth_csrf_state_matches_requires_equal_non_empty() {
        assert!(oauth_csrf_state_matches(Some("abc"), Some("abc")));
        assert!(!oauth_csrf_state_matches(Some("abc"), Some("xyz")));
        assert!(!oauth_csrf_state_matches(Some(""), Some("")));
        assert!(!oauth_csrf_state_matches(None, Some("abc")));
        assert!(!oauth_csrf_state_matches(Some("abc"), None));
    }

    #[test]
    fn allowed_return_to_accepts_allowed_hosts() {
        let _guard = env_test_lock();
        std::env::set_var("ALLOWED_HOSTS", "agrr.net,.run.app");
        std::env::remove_var("FRONTEND_URL");
        assert!(allowed_return_to("https://agrr.net/dashboard"));
        assert!(allowed_return_to("https://foo.run.app/plans"));
        assert!(!allowed_return_to("https://evil.example/plans"));
        std::env::remove_var("ALLOWED_HOSTS");
    }

    #[test]
    fn host_matches_pattern_supports_dot_prefix() {
        assert!(host_matches_pattern("foo.run.app", ".run.app"));
        assert!(!host_matches_pattern("notrun.app", ".run.app"));
    }

    #[test]
    fn frontend_url_env_guards_return_to() {
        let _guard = env_test_lock();
        std::env::set_var("FRONTEND_URL", "http://127.0.0.1:4200,http://localhost:4200");
        assert_eq!(default_frontend_home(), "http://127.0.0.1:4200/");

        std::env::set_var("FRONTEND_URL", "http://localhost:4200");
        assert!(allowed_return_to("http://localhost:4200/plans"));
        assert!(!allowed_return_to("http://127.0.0.1:4200/plans"));

        std::env::set_var(
            "FRONTEND_URL",
            "http://127.0.0.1:4200,http://localhost:4200",
        );
        assert!(allowed_return_to("http://127.0.0.1:4200/"));
        std::env::remove_var("FRONTEND_URL");
    }

    #[test]
    fn append_oauth_conversion_query_adds_param() {
        let out = append_oauth_conversion_query("http://localhost:4200/plans");
        assert!(out.contains("_agrr_oauth=1"));
    }

    #[test]
    fn google_oauth_redirect_uri_from_frontend_url() {
        let _guard = env_test_lock();
        std::env::set_var("FRONTEND_URL", "http://127.0.0.1:4200,http://localhost:4200");
        std::env::remove_var("GOOGLE_OAUTH_REDIRECT_URI");
        assert_eq!(
            google_oauth_redirect_uri(),
            "http://127.0.0.1:4200/auth/google_oauth2/callback"
        );
        std::env::remove_var("FRONTEND_URL");
    }

    #[test]
    fn normalize_oauth_return_to_hub_for_auth_paths() {
        let out = normalize_oauth_return_to("https://agrr.net/plans?tab=1");
        assert_eq!(
            out,
            "https://agrr.net/?_post_login=%2Fplans%3Ftab%3D1"
        );
    }

    #[test]
    fn normalize_oauth_return_to_keeps_public_plan_results() {
        let url = "https://agrr.net/public-plans/results?planId=756";
        assert_eq!(normalize_oauth_return_to(url), url);
    }

    #[test]
    fn google_oauth_redirect_uri_explicit_env_overrides() {
        let _guard = env_test_lock();
        std::env::set_var("FRONTEND_URL", "http://127.0.0.1:4200");
        std::env::set_var(
            "GOOGLE_OAUTH_REDIRECT_URI",
            "https://agrr.net/auth/google_oauth2/callback",
        );
        assert_eq!(
            google_oauth_redirect_uri(),
            "https://agrr.net/auth/google_oauth2/callback"
        );
        std::env::remove_var("GOOGLE_OAUTH_REDIRECT_URI");
        std::env::remove_var("FRONTEND_URL");
    }
}
