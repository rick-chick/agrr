//! Edge-injected rate limiter (Ruby: adapter `ContactMessageRateLimiter`).

/// Ruby: rate limiter `#track` returns `:ok` or `:rate_limited`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RateLimitTrackResult {
    Ok,
    RateLimited,
}

/// Ruby: `Adapters::ContactMessages::Services::ContactMessageRateLimiter` (injected at edge).
pub trait ContactMessageRateLimiterPort: Send + Sync {
    fn track(&self) -> RateLimitTrackResult;
}
