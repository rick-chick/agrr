//! Extract client session for public plan mutation authorization.

use agrr_domain::cultivation_plan::dtos::CultivationPlanRestAuth;
use axum::http::HeaderMap;
use axum_extra::extract::cookie::CookieJar;

pub const PUBLIC_PLAN_SESSION_HEADER: &str = "X-Public-Plan-Session";
pub const PUBLIC_PLAN_SESSION_COOKIE: &str = "public_plan_session";

pub fn extract_public_plan_session(headers: &HeaderMap, jar: &CookieJar) -> Option<String> {
    headers
        .get(PUBLIC_PLAN_SESSION_HEADER)
        .and_then(|v| v.to_str().ok())
        .map(str::to_string)
        .or_else(|| {
            jar.get(PUBLIC_PLAN_SESSION_COOKIE)
                .map(|cookie| cookie.value().to_string())
        })
        .filter(|value| !value.is_empty())
}

pub fn public_mutation_auth(headers: &HeaderMap, jar: &CookieJar) -> CultivationPlanRestAuth {
    let session_id = extract_public_plan_session(headers, jar).unwrap_or_default();
    CultivationPlanRestAuth::public_mutation(session_id)
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::HeaderValue;
    use axum_extra::extract::cookie::Cookie;

    #[test]
    fn extract_prefers_header_over_cookie() {
        let mut headers = HeaderMap::new();
        headers.insert(
            PUBLIC_PLAN_SESSION_HEADER,
            HeaderValue::from_static("header-session"),
        );
        let jar = CookieJar::new().add(Cookie::new(PUBLIC_PLAN_SESSION_COOKIE, "cookie-session"));
        assert_eq!(
            extract_public_plan_session(&headers, &jar).as_deref(),
            Some("header-session")
        );
    }

    #[test]
    fn extract_falls_back_to_cookie_when_header_missing() {
        let headers = HeaderMap::new();
        let jar = CookieJar::new().add(Cookie::new(PUBLIC_PLAN_SESSION_COOKIE, "cookie-session"));
        assert_eq!(
            extract_public_plan_session(&headers, &jar).as_deref(),
            Some("cookie-session")
        );
    }

    #[test]
    fn extract_returns_none_when_header_present_but_empty() {
        let mut headers = HeaderMap::new();
        headers.insert(PUBLIC_PLAN_SESSION_HEADER, HeaderValue::from_static(""));
        let jar = CookieJar::new().add(Cookie::new(PUBLIC_PLAN_SESSION_COOKIE, "cookie-session"));
        assert_eq!(extract_public_plan_session(&headers, &jar), None);
    }

    #[test]
    fn extract_returns_none_for_empty_header_and_empty_cookie() {
        let mut headers = HeaderMap::new();
        headers.insert(PUBLIC_PLAN_SESSION_HEADER, HeaderValue::from_static(""));
        let jar = CookieJar::new().add(Cookie::new(PUBLIC_PLAN_SESSION_COOKIE, ""));
        assert_eq!(extract_public_plan_session(&headers, &jar), None);
    }

    #[test]
    fn extract_returns_none_when_session_absent() {
        assert_eq!(
            extract_public_plan_session(&HeaderMap::new(), &CookieJar::new()),
            None
        );
    }

    #[test]
    fn public_mutation_auth_uses_extracted_session() {
        let mut headers = HeaderMap::new();
        headers.insert(
            PUBLIC_PLAN_SESSION_HEADER,
            HeaderValue::from_static("sess-42"),
        );
        let auth = public_mutation_auth(&headers, &CookieJar::new());
        assert_eq!(auth.public_session_id.as_deref(), Some("sess-42"));
    }
}
