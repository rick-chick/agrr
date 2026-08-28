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
