//! Per-user rate limits for Masters API (`/api/v1/masters/*`).

use axum::{
    body::Body,
    extract::{Request, State},
    http::{HeaderMap, HeaderValue, Method, StatusCode},
    middleware::Next,
    response::{IntoResponse, Response},
    Json,
};
use axum_extra::extract::cookie::CookieJar;
use serde_json::json;
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

use crate::masters_auth::resolve_masters_user_id;
use crate::state::AppState;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum MastersRateLimitTier {
    Read,
    DryRun,
    Write,
    Apply,
}

#[derive(Debug, Clone, Copy)]
pub struct MastersRateLimitConfig {
    pub read_per_min: u32,
    pub dry_run_per_min: u32,
    pub write_per_min: u32,
    pub apply_per_min: u32,
}

impl MastersRateLimitConfig {
    pub fn from_env() -> Self {
        let test_script = std::env::var("AGRR_TEST_SCRIPT").ok().as_deref() == Some("1");
        Self {
            read_per_min: env_limit("MASTERS_RATE_LIMIT_READ_PER_MIN", if test_script { 120 } else { 120 }),
            dry_run_per_min: env_limit("MASTERS_RATE_LIMIT_DRY_RUN_PER_MIN", if test_script { 30 } else { 30 }),
            write_per_min: env_limit("MASTERS_RATE_LIMIT_WRITE_PER_MIN", if test_script { 60 } else { 60 }),
            apply_per_min: env_limit("MASTERS_RATE_LIMIT_APPLY_PER_MIN", if test_script { 2 } else { 5 }),
        }
    }

    fn limit_for(&self, tier: MastersRateLimitTier) -> u32 {
        match tier {
            MastersRateLimitTier::Read => self.read_per_min,
            MastersRateLimitTier::DryRun => self.dry_run_per_min,
            MastersRateLimitTier::Write => self.write_per_min,
            MastersRateLimitTier::Apply => self.apply_per_min,
        }
    }
}

fn env_limit(name: &str, default: u32) -> u32 {
    std::env::var(name)
        .ok()
        .and_then(|v| v.parse().ok())
        .filter(|&n| n > 0)
        .unwrap_or(default)
}

#[derive(Debug)]
struct WindowEntry {
    window_start: Instant,
    count: u32,
}

pub struct MastersRateLimiter {
    config: MastersRateLimitConfig,
    buckets: Mutex<HashMap<(i64, MastersRateLimitTier), WindowEntry>>,
}

impl MastersRateLimiter {
    pub fn new(config: MastersRateLimitConfig) -> Self {
        Self {
            config,
            buckets: Mutex::new(HashMap::new()),
        }
    }

    /// Returns `Ok(())` or `Err(retry_after_seconds)`.
    pub fn check(&self, user_id: i64, tier: MastersRateLimitTier) -> Result<(), u64> {
        let limit = self.config.limit_for(tier);
        let now = Instant::now();
        let window = Duration::from_secs(60);
        let mut buckets = self.buckets.lock().expect("masters rate limit mutex");
        let key = (user_id, tier);
        let entry = buckets.entry(key).or_insert(WindowEntry {
            window_start: now,
            count: 0,
        });
        if now.duration_since(entry.window_start) >= window {
            entry.window_start = now;
            entry.count = 0;
        }
        if entry.count >= limit {
            let elapsed = now.duration_since(entry.window_start);
            let retry_after = window.saturating_sub(elapsed).as_secs().max(1);
            return Err(retry_after);
        }
        entry.count += 1;
        Ok(())
    }
}

pub fn classify_masters_request(
    method: &Method,
    path: &str,
    query: Option<&str>,
) -> Option<MastersRateLimitTier> {
    if !path.starts_with("/api/v1/masters/") {
        return None;
    }
    if path.contains("/setup_proposal") {
        let query = query.unwrap_or("");
        if query.contains("mode=apply") {
            return Some(MastersRateLimitTier::Apply);
        }
        if query.contains("mode=dry_run") {
            return Some(MastersRateLimitTier::DryRun);
        }
    }
    if *method == Method::GET || *method == Method::HEAD {
        return Some(MastersRateLimitTier::Read);
    }
    if matches!(
        *method,
        Method::POST | Method::PUT | Method::PATCH | Method::DELETE
    ) {
        return Some(MastersRateLimitTier::Write);
    }
    None
}

fn query_api_key(query: Option<&str>) -> Option<&str> {
    query.and_then(|q| {
        q.split('&').find_map(|pair| {
            let (k, v) = pair.split_once('=')?;
            if k == "api_key" { Some(v) } else { None }
        })
    })
}

fn rate_limit_response(retry_after: u64) -> Response {
    let mut headers = HeaderMap::new();
    headers.insert(
        "retry-after",
        HeaderValue::from_str(&retry_after.to_string()).unwrap_or(HeaderValue::from_static("60")),
    );
    (
        StatusCode::TOO_MANY_REQUESTS,
        headers,
        Json(json!({"error": "rate_limit"})),
    )
        .into_response()
}

pub async fn middleware(State(state): State<AppState>, request: Request, next: Next) -> Response {
    let method = request.method().clone();
    let path = request.uri().path().to_string();
    let query = request.uri().query().map(str::to_string);

    let Some(tier) = classify_masters_request(&method, &path, query.as_deref()) else {
        return next.run(request).await;
    };

    let (parts, body) = request.into_parts();
    let jar = CookieJar::from_headers(&parts.headers);
    let api_key = query_api_key(query.as_deref());
    match resolve_masters_user_id(&state, &jar, &parts.headers, api_key) {
        Ok(user_id) => {
            if let Err(retry_after) = state.masters_rate_limit.check(user_id, tier) {
                return rate_limit_response(retry_after);
            }
        }
        Err(_) => {
            // Authentication is enforced by handlers; do not rate-limit anonymous probes here.
        }
    }

    let request = Request::from_parts(parts, Body::from(body));
    next.run(request).await
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classify_apply_dry_run_and_read() {
        assert_eq!(
            classify_masters_request(
                &Method::POST,
                "/api/v1/masters/crops/1/setup_proposal",
                Some("mode=apply")
            ),
            Some(MastersRateLimitTier::Apply)
        );
        assert_eq!(
            classify_masters_request(
                &Method::POST,
                "/api/v1/masters/crops/1/setup_proposal",
                Some("mode=dry_run")
            ),
            Some(MastersRateLimitTier::DryRun)
        );
        assert_eq!(
            classify_masters_request(&Method::GET, "/api/v1/masters/crops", None),
            Some(MastersRateLimitTier::Read)
        );
        assert_eq!(
            classify_masters_request(&Method::POST, "/api/v1/masters/crops", None),
            Some(MastersRateLimitTier::Write)
        );
    }

    #[test]
    fn apply_limit_returns_retry_after() {
        let limiter = MastersRateLimiter::new(MastersRateLimitConfig {
            read_per_min: 10,
            dry_run_per_min: 10,
            write_per_min: 10,
            apply_per_min: 2,
        });
        assert!(limiter.check(42, MastersRateLimitTier::Apply).is_ok());
        assert!(limiter.check(42, MastersRateLimitTier::Apply).is_ok());
        let retry = limiter
            .check(42, MastersRateLimitTier::Apply)
            .expect_err("third apply should be limited");
        assert!(retry >= 1);
    }
}
