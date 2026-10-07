//! Edge-injected CAPTCHA verifier (Turnstile at the server edge).

/// Result of a CAPTCHA verification attempt.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CaptchaVerifyResult {
    Ok,
    /// User-facing rejection (retry CAPTCHA).
    Rejected(String),
    /// Temporary or configuration failure (503).
    Unavailable(String),
    /// Server misconfiguration (e.g. secret unset).
    NotConfigured,
}

/// Verifies CAPTCHA tokens before accepting contact messages.
pub trait CaptchaVerifierPort: Send + Sync {
    fn verify(&self, token: Option<&str>, remote_ip: Option<&str>) -> CaptchaVerifyResult;
}
