//! Resolve client locale from HTTP headers.

use axum::http::HeaderMap;

use crate::locale_catalog::normalize_locale;

pub fn locale_from_headers(headers: &HeaderMap) -> &'static str {
    if let Some(value) = headers.get("accept-language") {
        if let Ok(s) = value.to_str() {
            return match normalize_locale(s) {
                "en" => "en",
                "in" => "in",
                "ja" => "ja",
                _ => "ja",
            };
        }
    }
    "ja"
}
