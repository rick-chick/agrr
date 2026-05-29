//! Shared OAuth return_to validation (Rails `AuthController#allowed_return_to?` parity).

pub const OAUTH_RETURN_TO_COOKIE: &str = "oauth_return_to";

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

pub fn allowed_return_to(url: &str) -> bool {
    let Ok(uri) = url::Url::parse(url) else {
        return false;
    };
    if uri.scheme() != "http" && uri.scheme() != "https" {
        return false;
    }
    let origin = build_origin(&uri);
    frontend_origins().contains(&origin)
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

#[cfg(test)]
mod tests {
    use super::*;

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
    fn frontend_url_env_guards_return_to() {
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
}
