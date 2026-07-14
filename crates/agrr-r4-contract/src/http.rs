//! Blocking HTTP helpers for contract tests (mirrors `ContractTestCase#rust_*`).

use reqwest::blocking::{Client, Response};
use reqwest::header::{HeaderMap, HeaderValue, ACCEPT, CONTENT_TYPE, COOKIE};
use std::collections::HashMap;

pub struct ContractClient {
    base_url: String,
    client: Client,
}

impl ContractClient {
    pub fn from_env() -> Self {
        let base_url = std::env::var("RUST_CONTRACT_BASE_URL")
            .unwrap_or_else(|_| "http://127.0.0.1:8080".to_string())
            .trim_end_matches('/')
            .to_string();
        Self {
            base_url,
            client: Client::builder()
                .redirect(reqwest::redirect::Policy::none())
                .build()
                .expect("contract HTTP client"),
        }
    }

    pub fn get(
        &self,
        path: &str,
        session_id: Option<&str>,
        headers: &HashMap<String, String>,
    ) -> Response {
        self.request(reqwest::Method::GET, path, session_id, headers, None)
    }

    pub fn post(
        &self,
        path: &str,
        session_id: Option<&str>,
        headers: &HashMap<String, String>,
        body: Option<serde_json::Value>,
    ) -> Response {
        self.request(reqwest::Method::POST, path, session_id, headers, body)
    }

    pub fn patch(
        &self,
        path: &str,
        session_id: Option<&str>,
        headers: &HashMap<String, String>,
        body: Option<serde_json::Value>,
    ) -> Response {
        self.request(reqwest::Method::PATCH, path, session_id, headers, body)
    }

    pub fn put(
        &self,
        path: &str,
        session_id: Option<&str>,
        headers: &HashMap<String, String>,
        body: Option<serde_json::Value>,
    ) -> Response {
        self.request(reqwest::Method::PUT, path, session_id, headers, body)
    }

    pub fn put_bytes(
        &self,
        path: &str,
        session_id: Option<&str>,
        headers: &HashMap<String, String>,
        content_type: &str,
        body: &[u8],
    ) -> Response {
        let url = format!("{}{}", self.base_url, path);
        let mut header_map = HeaderMap::new();
        header_map.insert(ACCEPT, HeaderValue::from_static("application/json"));
        header_map.insert(
            CONTENT_TYPE,
            HeaderValue::from_str(content_type).expect("content type"),
        );
        if let Some(sid) = session_id {
            let cookie = format!("session_id={sid}");
            header_map.insert(COOKIE, HeaderValue::from_str(&cookie).expect("cookie"));
        }
        for (key, value) in headers {
            header_map.insert(
                reqwest::header::HeaderName::from_bytes(key.as_bytes()).unwrap_or_else(|_| {
                    panic!("invalid header name: {key}");
                }),
                HeaderValue::from_str(value).unwrap_or_else(|_| {
                    panic!("invalid header value for {key}");
                }),
            );
        }
        self.client
            .put(url)
            .headers(header_map)
            .body(body.to_vec())
            .send()
            .expect("contract HTTP put_bytes")
    }

    pub fn delete(
        &self,
        path: &str,
        session_id: Option<&str>,
        headers: &HashMap<String, String>,
    ) -> Response {
        self.request(reqwest::Method::DELETE, path, session_id, headers, None)
    }

    fn request(
        &self,
        method: reqwest::Method,
        path: &str,
        session_id: Option<&str>,
        extra_headers: &HashMap<String, String>,
        body: Option<serde_json::Value>,
    ) -> Response {
        let url = format!("{}{}", self.base_url, path);
        let mut req = self.client.request(method, &url);
        let mut header_map = HeaderMap::new();
        header_map.insert(ACCEPT, HeaderValue::from_static("application/json"));
        if body.is_some() {
            header_map.insert(CONTENT_TYPE, HeaderValue::from_static("application/json"));
        }
        if let Some(sid) = session_id {
            let cookie = format!("session_id={sid}");
            header_map.insert(COOKIE, HeaderValue::from_str(&cookie).expect("cookie"));
        }
        for (key, value) in extra_headers {
            header_map.insert(
                reqwest::header::HeaderName::from_bytes(key.as_bytes()).unwrap_or_else(|_| {
                    panic!("invalid header name: {key}");
                }),
                HeaderValue::from_str(value).unwrap_or_else(|_| {
                    panic!("invalid header value for {key}");
                }),
            );
        }
        req = req.headers(header_map);
        if let Some(json) = body {
            req = req.json(&json);
        }
        req.send().expect("contract HTTP request")
    }
}
