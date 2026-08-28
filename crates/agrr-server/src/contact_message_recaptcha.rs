//! Google reCAPTCHA verification for anonymous contact messages.

use agrr_domain::contact_messages::ports::{RecaptchaVerifierPort, RecaptchaVerifyResult};
use crate::runtime_env;
use reqwest::blocking::Client;
use serde::Deserialize;

const VERIFY_URL: &str = "https://www.google.com/recaptcha/api/siteverify";
const UNCONFIGURED_MESSAGE: &str = "reCAPTCHA verification unavailable";
const TOKEN_REQUIRED_MESSAGE: &str = "reCAPTCHA token required";

pub struct RecaptchaVerifier {
    secret_key: String,
    client: Option<Client>,
    verify_url: String,
    fail_closed_when_unconfigured: bool,
}

impl RecaptchaVerifier {
    pub fn from_env() -> Self {
        Self::new(std::env::var("RECAPTCHA_SECRET_KEY").unwrap_or_default())
    }

    pub fn new(secret_key: impl Into<String>) -> Self {
        Self::with_policy(secret_key, runtime_env::is_production())
    }

    fn with_policy(secret_key: impl Into<String>, fail_closed_when_unconfigured: bool) -> Self {
        let secret_key = secret_key.into();
        let client = if secret_key.trim().is_empty() {
            None
        } else {
            Some(Client::new())
        };
        Self {
            secret_key,
            client,
            verify_url: VERIFY_URL.to_string(),
            fail_closed_when_unconfigured,
        }
    }

    pub fn is_configured(&self) -> bool {
        !self.secret_key.trim().is_empty()
    }

    pub fn warn_if_unconfigured_at_startup() {
        if runtime_env::is_production() && !Self::from_env().is_configured() {
            eprintln!(
                "agrr-server: WARNING RECAPTCHA_SECRET_KEY is unset in production; contact_messages will reject submissions"
            );
        }
    }

    fn secret_missing_in_production(&self) -> bool {
        !self.is_configured() && self.fail_closed_when_unconfigured
    }

    fn token_missing(token: Option<&str>) -> bool {
        token.unwrap_or("").trim().is_empty()
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
}

#[derive(Debug, Deserialize)]
struct VerifyResponse {
    success: bool,
    #[serde(rename = "error-codes", default)]
    error_codes: Vec<String>,
}

impl RecaptchaVerifierPort for RecaptchaVerifier {
    fn verify(&self, token: Option<&str>, remote_ip: Option<&str>) -> RecaptchaVerifyResult {
        if self.secret_missing_in_production() {
            return RecaptchaVerifyResult::Error(UNCONFIGURED_MESSAGE.into());
        }

        if !self.is_configured() {
            return RecaptchaVerifyResult::Ok;
        }

        if Self::token_missing(token) {
            return RecaptchaVerifyResult::Error(TOKEN_REQUIRED_MESSAGE.into());
        }

        let token = token.unwrap_or_default();
        let mut form = vec![
            ("secret", self.secret_key.as_str()),
            ("response", token),
        ];
        let remote_ip = remote_ip.unwrap_or_default();
        if !remote_ip.is_empty() {
            form.push(("remoteip", remote_ip));
        }

        let client = match &self.client {
            Some(client) => client,
            None => return RecaptchaVerifyResult::Error(UNCONFIGURED_MESSAGE.into()),
        };

        let response = match client.post(&self.verify_url).form(&form).send() {
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn verify_bypasses_when_secret_missing_in_non_production() {
        let verifier = RecaptchaVerifier::with_policy("", false);
        assert_eq!(
            verifier.verify(Some("token"), Some("203.0.113.1")),
            RecaptchaVerifyResult::Ok
        );
    }

    #[test]
    fn verify_rejects_when_secret_missing_in_production() {
        let verifier = RecaptchaVerifier::with_policy("", true);
        match verifier.verify(Some("token"), Some("203.0.113.1")) {
            RecaptchaVerifyResult::Error(message) => {
                assert!(message.contains("reCAPTCHA"), "{message}");
            }
            other => panic!("expected error, got {other:?}"),
        }
    }

    #[test]
    fn verify_rejects_when_token_missing_and_secret_configured() {
        let verifier = RecaptchaVerifier::with_policy("secret", false);
        match verifier.verify(None, Some("203.0.113.1")) {
            RecaptchaVerifyResult::Error(message) => {
                assert!(message.contains("reCAPTCHA"), "{message}");
            }
            other => panic!("expected error, got {other:?}"),
        }
        match verifier.verify(Some(""), Some("203.0.113.1")) {
            RecaptchaVerifyResult::Error(message) => {
                assert!(message.contains("reCAPTCHA"), "{message}");
            }
            other => panic!("expected error, got {other:?}"),
        }
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
