//! Baseline security response headers for API routes (LB adds the same on production).

use axum::body::Body;
use axum::http::{header, Request, Response};
use axum::middleware::Next;
use axum::Router;

pub const STRICT_TRANSPORT_SECURITY: &str = "max-age=31536000; includeSubDomains";
pub const X_CONTENT_TYPE_OPTIONS: &str = "nosniff";
pub const REFERRER_POLICY: &str = "strict-origin-when-cross-origin";
pub const X_FRAME_OPTIONS: &str = "SAMEORIGIN";
pub const CONTENT_SECURITY_POLICY_REPORT_ONLY: &str = concat!(
    "default-src 'self'; ",
    "script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.googletagmanager.com https://www.google-analytics.com; ",
    "connect-src 'self' https://www.google-analytics.com https://www.googletagmanager.com; ",
    "img-src 'self' data: https:; ",
    "style-src 'self' 'unsafe-inline'; ",
    "frame-ancestors 'self'"
);

pub fn apply_security_headers_layer<S>(router: Router<S>) -> Router<S>
where
    S: Clone + Send + Sync + 'static,
{
    router.layer(axum::middleware::from_fn(security_headers_middleware))
}

pub async fn security_headers_middleware(request: Request<Body>, next: Next) -> Response<Body> {
    let mut response = next.run(request).await;
    let headers = response.headers_mut();
    insert_if_absent(headers, header::STRICT_TRANSPORT_SECURITY, STRICT_TRANSPORT_SECURITY);
    insert_if_absent(headers, header::X_CONTENT_TYPE_OPTIONS, X_CONTENT_TYPE_OPTIONS);
    insert_if_absent(headers, header::REFERRER_POLICY, REFERRER_POLICY);
    insert_if_absent(headers, header::X_FRAME_OPTIONS, X_FRAME_OPTIONS);
    insert_if_absent(
        headers,
        header::HeaderName::from_static("content-security-policy-report-only"),
        CONTENT_SECURITY_POLICY_REPORT_ONLY,
    );
    response
}

fn insert_if_absent(headers: &mut axum::http::HeaderMap, name: header::HeaderName, value: &str) {
    if headers.contains_key(&name) {
        return;
    }
    if let Ok(parsed) = header::HeaderValue::from_str(value) {
        headers.insert(name, parsed);
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use axum::routing::get;
    use axum::Router;
    use tower::util::ServiceExt;

    fn test_app() -> Router {
        apply_security_headers_layer(Router::new().route("/health", get(|| async { "ok" })))
    }

    #[tokio::test]
    async fn health_response_includes_baseline_security_headers() {
        let app = test_app();
        let response = app
            .oneshot(
                Request::builder()
                    .uri("/health")
                    .body(Body::empty())
                    .expect("request"),
            )
            .await
            .expect("response");

        let headers = response.headers();
        assert_eq!(
            STRICT_TRANSPORT_SECURITY,
            headers
                .get(header::STRICT_TRANSPORT_SECURITY)
                .expect("hsts")
                .to_str()
                .expect("hsts value")
        );
        assert_eq!(
            X_CONTENT_TYPE_OPTIONS,
            headers
                .get(header::X_CONTENT_TYPE_OPTIONS)
                .expect("nosniff")
                .to_str()
                .expect("nosniff value")
        );
        assert_eq!(
            REFERRER_POLICY,
            headers
                .get(header::REFERRER_POLICY)
                .expect("referrer")
                .to_str()
                .expect("referrer value")
        );
        assert_eq!(
            X_FRAME_OPTIONS,
            headers
                .get(header::X_FRAME_OPTIONS)
                .expect("frame")
                .to_str()
                .expect("frame value")
        );
        assert!(
            headers
                .get("content-security-policy-report-only")
                .is_some(),
            "csp report-only header"
        );
    }
}
