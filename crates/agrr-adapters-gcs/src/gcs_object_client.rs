//! GCS JSON API + local FS — authenticated read/write/list (Ruby SDK parity).

use std::fs;
use std::io::Write;
use std::path::Path;
use std::sync::OnceLock;

use reqwest::blocking::Client;
use reqwest::StatusCode;
use serde_json::Value;

use crate::weather_json::{WeatherDataGcsConfig, WeatherDataGcsError};

pub struct GcsObjectClient {
    config: WeatherDataGcsConfig,
    http: Client,
}

/// One process-wide blocking client. Per-request `Client::new()` + drop inside Tokio workers panics.
fn shared_blocking_http_client() -> &'static Client {
    static CLIENT: OnceLock<Client> = OnceLock::new();
    CLIENT.get_or_init(Client::new)
}

/// Initialize the process-wide blocking client off the Tokio runtime (safe from `#[tokio::main]`).
pub fn preload_blocking_http_client() {
    std::thread::Builder::new()
        .name("gcs-blocking-http-init".into())
        .spawn(|| {
            let _ = shared_blocking_http_client();
        })
        .expect("spawn gcs blocking http init thread")
        .join()
        .expect("join gcs blocking http init thread");
}

impl GcsObjectClient {
    pub fn new(config: WeatherDataGcsConfig) -> Self {
        Self {
            config,
            http: shared_blocking_http_client().clone(),
        }
    }

    pub fn uses_remote_gcs(&self) -> bool {
        self.config.use_http && self.config.local_root.is_none()
    }

    /// Missing object or local file — not a transport failure.
    pub fn read_object(&self, key: &str) -> Result<Option<Vec<u8>>, WeatherDataGcsError> {
        if let Some(root) = &self.config.local_root {
            let path = root.join(key);
            if !path.exists() {
                return Ok(None);
            }
            return Ok(Some(fs::read(path)?));
        }
        if !self.uses_remote_gcs() {
            return Ok(None);
        }
        let token = match test_access_token() {
            Some(t) => t,
            None => gcp_access_token(&self.http)?,
        };
        let url = object_media_url(&self.config.bucket, key);
        let resp = self.http.get(url).bearer_auth(&token).send()?;
        match resp.status() {
            StatusCode::NOT_FOUND => Ok(None),
            s if s.is_success() => Ok(Some(resp.bytes()?.to_vec())),
            s => Err(WeatherDataGcsError::HttpStatus {
                status: s.as_u16(),
                message: resp.text().unwrap_or_default(),
            }),
        }
    }

    pub fn write_object(&self, key: &str, bytes: &[u8]) -> Result<(), WeatherDataGcsError> {
        if let Some(root) = &self.config.local_root {
            let path = root.join(key);
            if let Some(parent) = path.parent() {
                fs::create_dir_all(parent)?;
            }
            let mut file = fs::File::create(path)?;
            file.write_all(bytes)?;
            return Ok(());
        }
        if !self.uses_remote_gcs() {
            return Err(WeatherDataGcsError::MissingBucket);
        }
        let token = gcp_access_token(&self.http)?;
        let upload_url = format!(
            "https://storage.googleapis.com/upload/storage/v1/b/{}/o?uploadType=media&name={}",
            self.config.bucket,
            urlencoding_key(key)
        );
        self.http
            .post(upload_url)
            .bearer_auth(&token)
            .header("Content-Type", "application/json")
            .body(bytes.to_vec())
            .send()?
            .error_for_status()?;
        Ok(())
    }

    pub fn list_object_names(&self, prefix: &str) -> Result<Vec<String>, WeatherDataGcsError> {
        if let Some(root) = &self.config.local_root {
            return list_local_prefix(root, prefix);
        }
        if !self.uses_remote_gcs() {
            return Ok(Vec::new());
        }
        let token = gcp_access_token(&self.http)?;
        let mut names = Vec::new();
        let mut page_token: Option<String> = None;
        loop {
            let mut url = format!(
                "https://storage.googleapis.com/storage/v1/b/{}/o?prefix={}",
                self.config.bucket,
                urlencoding_key(prefix)
            );
            if let Some(ref token) = page_token {
                url.push_str("&pageToken=");
                url.push_str(&urlencoding_key(token));
            }
            let body: Value = self
                .http
                .get(&url)
                .bearer_auth(&token)
                .send()?
                .error_for_status()?
                .json()?;
            if let Some(items) = body.get("items").and_then(|v| v.as_array()) {
                for item in items {
                    if let Some(name) = item.get("name").and_then(|v| v.as_str()) {
                        names.push(name.to_string());
                    }
                }
            }
            page_token = body
                .get("nextPageToken")
                .and_then(|v| v.as_str())
                .map(|s| s.to_string());
            if page_token.is_none() {
                break;
            }
        }
        Ok(names)
    }
}

fn list_local_prefix(root: &Path, prefix: &str) -> Result<Vec<String>, WeatherDataGcsError> {
    let dir = root.join(prefix);
    if !dir.is_dir() {
        return Ok(Vec::new());
    }
    let mut names = Vec::new();
    for entry in fs::read_dir(&dir)? {
        let entry = entry?;
        let file_name = entry.file_name();
        let file_name = file_name.to_string_lossy();
        names.push(format!("{prefix}{file_name}"));
    }
    Ok(names)
}

pub fn urlencoding_key(key: &str) -> String {
    key.split('/')
        .map(|segment| {
            segment
                .chars()
                .map(|c| match c {
                    'A'..='Z' | 'a'..='z' | '0'..='9' | '-' | '_' | '.' | '~' => c.to_string(),
                    _ => format!("%{:02X}", c as u8),
                })
                .collect::<String>()
        })
        .collect::<Vec<_>>()
        .join("%2F")
}

fn object_media_url(bucket: &str, key: &str) -> String {
    if let Ok(base) = std::env::var("GCS_API_BASE_URL") {
        let base = base.trim_end_matches('/');
        return format!(
            "{base}/storage/v1/b/{bucket}/o/{}?alt=media",
            urlencoding_key(key)
        );
    }
    format!(
        "https://storage.googleapis.com/storage/v1/b/{bucket}/o/{}?alt=media",
        urlencoding_key(key)
    )
}

fn test_access_token() -> Option<String> {
    std::env::var("GCS_TEST_ACCESS_TOKEN").ok()
}

fn gcp_access_token(http: &Client) -> Result<String, WeatherDataGcsError> {
    let resp = http
        .get("http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token")
        .header("Metadata-Flavor", "Google")
        .query(&[(
            "scopes",
            "https://www.googleapis.com/auth/devstorage.read_write",
        )])
        .send()?;
    if !resp.status().is_success() {
        return Err(WeatherDataGcsError::AuthFailed);
    }
    let body: Value = resp.json()?;
    body.get("access_token")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
        .ok_or(WeatherDataGcsError::AuthFailed)
}

#[cfg(test)]
mod gcs_object_client_http_tests {
    use super::*;

    #[test]
    #[ignore = "integration: mock HTTP 403; run cargo test -p agrr-adapters-gcs -- --ignored"]
    fn read_object_returns_http_status_on_403_not_empty() {
        let mut server = mockito::Server::new();
        let _mock = server
            .mock("GET", mockito::Matcher::Regex(r"/storage/v1/b/test-bucket/o/.*".into()))
            .with_status(403)
            .with_body("Forbidden")
            .create();

        std::env::set_var("GCS_API_BASE_URL", server.url());
        std::env::set_var("GCS_TEST_ACCESS_TOKEN", "test-token");

        let config = WeatherDataGcsConfig {
            bucket: "test-bucket".into(),
            use_http: true,
            local_root: None,
        };
        let client = GcsObjectClient::new(config);
        let key = "weather_data/1/2024.json";
        let result = client.read_object(key);
        std::env::remove_var("GCS_API_BASE_URL");
        std::env::remove_var("GCS_TEST_ACCESS_TOKEN");

        let Err(WeatherDataGcsError::HttpStatus { status, .. }) = result else {
            panic!("expected HttpStatus error, got {result:?}");
        };
        assert_eq!(status, 403);
    }
}
