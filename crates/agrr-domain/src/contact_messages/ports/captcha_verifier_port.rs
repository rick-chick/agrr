//! Edge-injected CAPTCHA verifier (Turnstile at the edge).

/// Result of server-side CAPTCHA verification.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CaptchaVerifyResult {
    Ok,
    /// User-recoverable rejection (missing/invalid/expired token).
    Rejected(String),
    /// Misconfiguration or transient upstream failure.
    Unavailable(String),
    /// Secret not configured (fail-closed).
    NotConfigured,
}

/// Ruby: `Adapters::ContactMessages::Services::*Verifier` (injected at edge).
pub trait CaptchaVerifierPort: Send + Sync {
    fn verify(&self, token: Option<&str>, remote_ip: Option<&str>) -> CaptchaVerifyResult;
}
