//! Edge-injected reCAPTCHA verifier (Ruby: adapter `RecaptchaVerifier`).

/// Ruby adapter returns `:ok` or `[:error, message]`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum RecaptchaVerifyResult {
    Ok,
    Error(String),
}

/// Ruby: `Adapters::ContactMessages::Services::RecaptchaVerifier` (injected at edge).
pub trait RecaptchaVerifierPort: Send + Sync {
    fn verify(&self, token: Option<&str>, remote_ip: Option<&str>) -> RecaptchaVerifyResult;
}
