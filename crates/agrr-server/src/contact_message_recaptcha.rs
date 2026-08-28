//! Google reCAPTCHA verification for anonymous contact messages.

use agrr_domain::contact_messages::ports::{RecaptchaVerifierPort, RecaptchaVerifyResult};
use reqwest::blocking::Client;
use serde::Deserialize;

const VERIFY_URL: &str = "https://www.google.com/recaptcha/api/siteverify";

pub struct RecaptchaVerifier {
    secret_key: String,
    verify_url: String,
}

impl RecaptchaVerifier {
    pub fn from_env() -> Self {
        let verifier = Self::new(
            std::env::var("RECAPTCHA_SECRET_KEY").unwrap_or_default(),
            std::env::var("RECAPTCHA_VERIFY_URL").unwrap_or_else(|_| VERIFY_URL.to_string()),
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
                "RECAPTCHA_SECRET_KEY is unset; contact message submissions will be rejected"
            );
        }
    }

    #[cfg(test)]
    pub fn with_verify_url(secret_key: impl Into<String>, verify_url: impl Into<String>) -> Self {
        Self::new(secret_key, verify_url)
    }

    fn parse_verify_response(body: &str) -> RecaptchaVerifyResult {
        let payload: VerifyResponse = match serde_json::from_str(body) {
            Ok(payload) => payload,
            Err(err) => {
                return RecaptchaVerifyResult::Error(format!(
                    "reCAPTCHA verification failed: {err}"
                ));
            }
        };
        if payload.success {
            RecaptchaVerifyResult::Ok
        } else {
            RecaptchaVerifyResult::Error(Self::error_message(&payload))
        }
    }

    fn error_message(payload: &VerifyResponse) -> String {
        if payload.error_codes.is_empty() {
            return "reCAPTCHA verification failed".to_string();
        }
        format!(
            "reCAPTCHA failure: {}",
            payload
                .error_codes
                .iter()
                .map(String::as_str)
                .collect::<Vec<_>>()
                .join(", ")
        )
    }

    fn verify_on_blocking_thread(
        secret_key: String,
        verify_url: String,
        token: String,
        remote_ip: String,
    ) -> RecaptchaVerifyResult {
        let mut form = vec![
            ("secret", secret_key.as_str()),
            ("response", token.as_str()),
        ];
        if !remote_ip.is_empty() {
            form.push(("remoteip", remote_ip.as_str()));
        }

        let client = Client::new();
        let response = match client.post(&verify_url).form(&form).send() {
            Ok(response) => response,
            Err(err) => {
                return RecaptchaVerifyResult::Error(format!(
                    "reCAPTCHA verification error: {err}"
                ));
            }
        };

        let body = match response.text() {
            Ok(body) => body,
            Err(err) => {
                return RecaptchaVerifyResult::Error(format!(
                    "reCAPTCHA verification error: {err}"
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

impl RecaptchaVerifierPort for RecaptchaVerifier {
    fn verify(&self, token: Option<&str>, remote_ip: Option<&str>) -> RecaptchaVerifyResult {
        if !self.is_configured() {
            return RecaptchaVerifyResult::NotConfigured;
        }

        if token.unwrap_or("").trim().is_empty() {
            return RecaptchaVerifyResult::Error("reCAPTCHA token is required".into());
        }

        let secret_key = self.secret_key.clone();
        let verify_url = self.verify_url.clone();
        let token = token.unwrap().to_string();
        let remote_ip = remote_ip.unwrap_or_default().to_string();

        std::thread::Builder::new()
            .name("recaptcha-verify".into())
            .spawn(move || {
                Self::verify_on_blocking_thread(secret_key, verify_url, token, remote_ip)
            })
            .expect("recaptcha verify thread spawn")
            .join()
            .unwrap_or(RecaptchaVerifyResult::Error(
                "reCAPTCHA verification thread failed".into(),
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

    fn spawn_mock_verify_server(response_body: &str) -> (String, thread::JoinHandle<()>) {
        let listener = TcpListener::bind("127.0.0.1:0").expect("bind mock verify server");
        let addr = listener.local_addr().expect("mock verify addr");
        let body = response_body.to_string();
        let (ready_tx, ready_rx) = mpsc::channel();
        let handle = thread::spawn(move || {
            ready_tx.send(()).ok();
            if let Ok((mut stream, _)) = listener.accept() {
                let mut buf = [0u8; 4096];
                let _ = stream.read(&mut buf);
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
        (format!("http://{addr}/siteverify"), handle)
    }

    #[test]
    fn verify_rejects_when_secret_missing() {
        let verifier = RecaptchaVerifier::new("", "http://example.test/verify");
        assert_eq!(
            verifier.verify(Some("token"), Some("203.0.113.1")),
            RecaptchaVerifyResult::NotConfigured
        );
    }

    #[test]
    fn verify_rejects_when_token_missing() {
        let verifier = RecaptchaVerifier::new("secret", "http://example.test/verify");
        assert_eq!(
            verifier.verify(None, Some("203.0.113.1")),
            RecaptchaVerifyResult::Error("reCAPTCHA token is required".into())
        );
        assert_eq!(
            verifier.verify(Some(""), Some("203.0.113.1")),
            RecaptchaVerifyResult::Error("reCAPTCHA token is required".into())
        );
    }

    #[test]
    fn verify_calls_siteverify_when_secret_and_token_present() {
        let (verify_url, handle) =
            spawn_mock_verify_server(r#"{"success":true,"error-codes":[]}"#);
        let verifier = RecaptchaVerifier::with_verify_url("secret", verify_url);
        assert_eq!(
            verifier.verify(Some("token"), Some("203.0.113.1")),
            RecaptchaVerifyResult::Ok
        );
        handle.join().expect("mock verify server thread");
    }

    #[test]
    fn parse_verify_response_maps_failure_to_error_message() {
        match RecaptchaVerifier::parse_verify_response(
            r#"{"success":false,"error-codes":["invalid-input-response"]}"#,
        ) {
            RecaptchaVerifyResult::Error(message) => {
                assert!(message.contains("invalid-input-response"), "{message}");
            }
            other => panic!("expected error, got {other:?}"),
        }
    }
}
