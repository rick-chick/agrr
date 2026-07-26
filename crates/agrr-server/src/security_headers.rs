//! Baseline security response headers for agrr-server HTTP responses.

use axum::{
    body::Body,
    http::{header::HeaderName, HeaderValue, Request, Response},
    middleware::Next,
};

/// Header name/value pairs applied to every agrr-server response.
pub const RESPONSE_HEADERS: [(&str, &str); 5] = [
    (
        "strict-transport-security",
        "max-age=31536000; includeSubDomains",
    ),
    ("x-content-type-options", "nosniff"),
    ("referrer-policy", "strict-origin-when-cross-origin"),
    ("x-frame-options", "DENY"),
    (
        "content-security-policy-report-only",
        "default-src 'self'; script-src 'self' 'unsafe-inline' https://www.googletagmanager.com https://www.google-analytics.com; connect-src 'self' https://www.google-analytics.com https://region1.google-analytics.com https://www.googletagmanager.com; img-src 'self' data: https://www.google-analytics.com https://www.googletagmanager.com; style-src 'self' 'unsafe-inline'; frame-ancestors 'none'",
    ),
];

pub async fn middleware(request: Request<Body>, next: Next) -> Response<Body> {
    let mut response = next.run(request).await;
    let headers = response.headers_mut();
    for (name, value) in RESPONSE_HEADERS {
        if let (Ok(parsed_name), Ok(parsed_value)) = (
            HeaderName::from_bytes(name.as_bytes()),
            HeaderValue::from_str(value),
        ) {
            headers.insert(parsed_name, parsed_value);
        }
    }
    response
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn response_headers_include_required_baseline() {
        let names: Vec<&str> = RESPONSE_HEADERS.iter().map(|(name, _)| *name).collect();
        assert!(names.contains(&"strict-transport-security"));
        assert!(names.contains(&"x-content-type-options"));
        assert!(names.contains(&"referrer-policy"));
        assert!(names.contains(&"x-frame-options"));
        assert!(names.contains(&"content-security-policy-report-only"));
    }

    #[test]
    fn response_header_values_are_valid_http() {
        for (name, value) in RESPONSE_HEADERS {
            HeaderValue::from_str(value)
                .unwrap_or_else(|_| panic!("invalid header value for {name}: {value}"));
        }
    }
}
