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

#[cfg(test)]
mod tests {
    use super::*;
    use axum::http::{HeaderMap, HeaderValue};

    #[test]
    fn locale_from_headers_prefers_accept_language() {
        let mut headers = HeaderMap::new();
        headers.insert(
            "accept-language",
            HeaderValue::from_static("hi-IN,en;q=0.8"),
        );
        assert_eq!(locale_from_headers(&headers), "in");
    }

    #[test]
    fn locale_from_headers_defaults_to_ja_when_missing_or_invalid() {
        assert_eq!(locale_from_headers(&HeaderMap::new()), "ja");

        let mut headers = HeaderMap::new();
        headers.insert(
            "accept-language",
            HeaderValue::from_bytes(&[0xff]).unwrap(),
        );
        assert_eq!(locale_from_headers(&headers), "ja");
    }

    #[test]
    fn locale_from_headers_maps_us_and_en_tags() {
        let mut headers = HeaderMap::new();
        headers.insert("accept-language", HeaderValue::from_static("us"));
        assert_eq!(locale_from_headers(&headers), "en");

        headers.insert("accept-language", HeaderValue::from_static("en-GB"));
        assert_eq!(locale_from_headers(&headers), "en");
    }
}
