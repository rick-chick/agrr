//! Cloudflare Turnstile verification for anonymous contact messages.

use agrr_domain::contact_messages::ports::{CaptchaVerifierPort, CaptchaVerifyResult};
use reqwest::blocking::Client;
use serde::Deserialize;
use std::net::IpAddr;
use std::time::Duration;

const VERIFY_URL: &str = "https://challenges.cloudflare.com/turnstile/v0/siteverify";
const VERIFY_TIMEOUT: Duration = Duration::from_secs(10);

pub struct TurnstileVerifier {
    secret_key: String,
    verify_url: String,
}

impl TurnstileVerifier {
    pub fn from_env() -> Self {
        let verifier = Self::new(
            std::env::var("TURNSTILE_SECRET_KEY").unwrap_or_default(),
            std::env::var("TURNSTILE_VERIFY_URL").unwrap_or_else(|_| VERIFY_URL.to_string()),
        );
        verifier.warn_if_unconfigured();
        verifier
    }

    pub fn new(secret_key: impl Into<String>, verify_url: impl Into<String>) -> Self {
        Self {
            secret_key: secret_key.into(),
            verify_url: verify_url.into(),
        }
    }

    pub fn is_configured(&self) -> bool {
        !self.secret_key.trim().is_empty()
    }

    pub fn warn_if_unconfigured(&self) {
        if !self.is_configured() {
            tracing::warn!(
                "TURNSTILE_SECRET_KEY is unset; contact message submissions will be rejected"
            );
        }
    }

    #[cfg(test)]
    pub fn with_verify_url(secret_key: impl Into<String>, verify_url: impl Into<String>) -> Self {
        Self::new(secret_key, verify_url)
    }

    fn remote_ip_for_form(remote_ip: Option<&str>) -> Option<String> {
        let value = remote_ip?.trim();
        if value.is_empty() || value == "unknown" {
            return None;
        }
        if value.parse::<IpAddr>().is_ok() {
            return Some(value.to_string());
        }
        None
    }

    fn error_message(error_codes: &[String]) -> String {
        if error_codes.is_empty() {
            return "Turnstile verification failed".to_string();
        }
        format!(
            "Turnstile failure: {}",
            error_codes
                .iter()
                .map(String::as_str)
                .collect::<Vec<_>>()
                .join(", ")
        )
    }

    fn classify_failure(error_codes: &[String]) -> CaptchaVerifyResult {
        const REJECTED: &[&str] = &[
            "missing-input-response",
            "invalid-input-response",
            "timeout-or-duplicate",
        ];
        const UNAVAILABLE: &[&str] = &[
            "missing-input-secret",
            "invalid-input-secret",
            "bad-request",
            "internal-error",
        ];
        for code in error_codes {
            if REJECTED.contains(&code.as_str()) {
                return CaptchaVerifyResult::Rejected(Self::error_message(error_codes));
            }
            if UNAVAILABLE.contains(&code.as_str()) {
                return CaptchaVerifyResult::Unavailable(Self::error_message(error_codes));
            }
        }
        CaptchaVerifyResult::Rejected(Self::error_message(error_codes))
    }

    fn parse_verify_response(body: &str) -> CaptchaVerifyResult {
        let payload: VerifyResponse = match serde_json::from_str(body) {
            Ok(payload) => payload,
            Err(err) => {
                return CaptchaVerifyResult::Unavailable(format!(
                    "Turnstile verification failed: {err}"
                ));
            }
        };
        if payload.success {
            CaptchaVerifyResult::Ok
        } else {
            Self::classify_failure(&payload.error_codes)
        }
    }

    fn verify_on_blocking_thread(
        secret_key: String,
        verify_url: String,
        token: String,
        remote_ip: Option<String>,
    ) -> CaptchaVerifyResult {
        let mut form = vec![
            ("secret", secret_key.as_str()),
            ("response", token.as_str()),
        ];
        if let Some(ip) = remote_ip.as_deref() {
            form.push(("remoteip", ip));
        }

        let client = Client::builder()
            .timeout(VERIFY_TIMEOUT)
            .build()
            .unwrap_or_else(|_| Client::new());
        let response = match client.post(&verify_url).form(&form).send() {
            Ok(response) => response,
            Err(err) => {
                return CaptchaVerifyResult::Unavailable(format!(
                    "Turnstile verification error: {err}"
                ));
            }
        };

        let body = match response.text() {
            Ok(body) => body,
            Err(err) => {
                return CaptchaVerifyResult::Unavailable(format!(
                    "Turnstile verification error: {err}"
                ));
            }
        };

        Self::parse_verify_response(&body)
    }
}

#[derive(Debug, Deserialize)]
struct VerifyResponse {
    success: bool,
    #[serde(rename = "error-codes", default)]
    error_codes: Vec<String>,
}

impl CaptchaVerifierPort for TurnstileVerifier {
    fn verify(&self, token: Option<&str>, remote_ip: Option<&str>) -> CaptchaVerifyResult {
        if !self.is_configured() {
            return CaptchaVerifyResult::NotConfigured;
        }

        if token.unwrap_or("").trim().is_empty() {
            return CaptchaVerifyResult::Rejected("Turnstile token is required".into());
        }

        let secret_key = self.secret_key.clone();
        let verify_url = self.verify_url.clone();
        let token = token.unwrap().to_string();
        let remote_ip = Self::remote_ip_for_form(remote_ip);

        std::thread::Builder::new()
            .name("turnstile-verify".into())
            .spawn(move || {
                Self::verify_on_blocking_thread(secret_key, verify_url, token, remote_ip)
            })
            .expect("turnstile verify thread spawn")
            .join()
            .unwrap_or(CaptchaVerifyResult::Unavailable(
                "Turnstile verification thread failed".into(),
            ))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::{Read, Write};
    use std::net::TcpListener;
    use std::sync::mpsc;
    use std::thread;
    use std::time::Duration;

    fn spawn_mock_verify_server(response_body: &str) -> (String, thread::JoinHandle<()>, mpsc::Receiver<String>) {
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind mock verify server");
        let addr = listener.local_addr().expect("mock verify addr");
        let body = response_body.to_string();
        let (ready_tx, ready_rx) = mpsc::channel();
        let (body_tx, body_rx) = mpsc::channel();
        let handle = thread::spawn(move || {
            ready_tx.send(()).ok();
            if let Ok((mut stream, _)) = listener.accept() {
                let mut buf = [0u8; 8192];
                let read = stream.read(&mut buf).expect("read request");
                body_tx.send(String::from_utf8_lossy(&buf[..read]).to_string()).ok();
                let response = format!(
                    "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nContent-Type: application/json\r\n\r\n{}",
                    body.len(),
                    body
                );
                let _ = stream.write_all(response.as_bytes());
            }
        });
        ready_rx
            .recv_timeout(Duration::from_secs(1))
            .expect("mock verify server ready");
        (format!("http://{addr}/siteverify"), handle, body_rx)
    }

    #[test]
    fn verify_rejects_when_secret_missing() {
        let verifier = TurnstileVerifier::new("", "http://example.test/verify");
        assert_eq!(
            verifier.verify(Some("token"), Some("203.0.113.1")),
            CaptchaVerifyResult::NotConfigured
        );
    }

    #[test]
    fn verify_rejects_when_token_missing() {
        let verifier = TurnstileVerifier::new("secret", "http://example.test/verify");
        assert_eq!(
            verifier.verify(None, Some("203.0.113.1")),
            CaptchaVerifyResult::Rejected("Turnstile token is required".into())
        );
        assert_eq!(
            verifier.verify(Some(""), Some("203.0.113.1")),
            CaptchaVerifyResult::Rejected("Turnstile token is required".into())
        );
    }

    #[test]
    fn verify_calls_siteverify_when_secret_and_token_present() {
        let (verify_url, handle, body_rx) =
            spawn_mock_verify_server(r#"{"success":true,"error-codes":[]}"#);
        let verifier = TurnstileVerifier::with_verify_url("secret", verify_url);
        assert_eq!(
            verifier.verify(Some("token"), Some("203.0.113.1")),
            CaptchaVerifyResult::Ok
        );
        let request = body_rx.recv_timeout(Duration::from_secs(1)).expect("request body");
        assert!(request.contains("secret=secret"));
        assert!(request.contains("response=token"));
        assert!(request.contains("remoteip=203.0.113.1"));
        handle.join().expect("mock verify server thread");
    }

    #[test]
    fn verify_omits_remoteip_for_unknown() {
        let (verify_url, handle, body_rx) =
            spawn_mock_verify_server(r#"{"success":true,"error-codes":[]}"#);
        let verifier = TurnstileVerifier::with_verify_url("secret", verify_url);
        assert_eq!(
            verifier.verify(Some("token"), Some("unknown")),
            CaptchaVerifyResult::Ok
        );
        let request = body_rx.recv_timeout(Duration::from_secs(1)).expect("request body");
        assert!(!request.contains("remoteip"));
        handle.join().expect("mock verify server thread");
    }

    #[test]
    fn classify_invalid_input_response_as_rejected() {
        match TurnstileVerifier::parse_verify_response(
            r#"{"success":false,"error-codes":["invalid-input-response"]}"#,
        ) {
            CaptchaVerifyResult::Rejected(message) => {
                assert!(message.contains("invalid-input-response"), "{message}");
            }
            other => panic!("expected rejected, got {other:?}"),
        }
    }

    #[test]
    fn classify_invalid_input_secret_as_unavailable() {
        match TurnstileVerifier::parse_verify_response(
            r#"{"success":false,"error-codes":["invalid-input-secret"]}"#,
        ) {
            CaptchaVerifyResult::Unavailable(message) => {
                assert!(message.contains("invalid-input-secret"), "{message}");
            }
            other => panic!("expected unavailable, got {other:?}"),
        }
    }

    #[test]
    fn default_verify_url_is_turnstile_siteverify() {
        assert_eq!(
            VERIFY_URL,
            "https://challenges.cloudflare.com/turnstile/v0/siteverify"
        );
    }
}
