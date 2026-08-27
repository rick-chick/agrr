//! IP-based rate limiting for anonymous `POST /api/v1/contact_messages`.

use agrr_domain::contact_messages::ports::{
    ContactMessageRateLimiterPort, RateLimitTrackResult,
};
use std::collections::HashMap;
use std::sync::Mutex;
use std::time::{Duration, Instant};

const DEFAULT_LIMIT_CONFIG: &str = "10/min";
const DEFAULT_PERIOD_SECS: u64 = 60;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct ContactMessageRateLimitConfig {
    pub limit: u32,
    pub period_secs: u64,
}

impl ContactMessageRateLimitConfig {
    pub fn from_env() -> Self {
        parse_limit_config(
            std::env::var("CONTACT_RATE_LIMIT")
                .ok()
                .filter(|v| !v.trim().is_empty())
                .as_deref()
                .unwrap_or(DEFAULT_LIMIT_CONFIG),
        )
    }
}

pub fn parse_limit_config(value: &str) -> ContactMessageRateLimitConfig {
    let trimmed = value.trim();
    if let Some((limit_str, period_str)) = trimmed.split_once('/') {
        let limit = limit_str.trim().parse().unwrap_or(10);
        let period_secs = period_seconds(period_str.trim());
        return ContactMessageRateLimitConfig { limit, period_secs };
    }
    if let Ok(limit) = trimmed.parse::<u32>() {
        return ContactMessageRateLimitConfig {
            limit,
            period_secs: DEFAULT_PERIOD_SECS,
        };
    }
    ContactMessageRateLimitConfig {
        limit: 10,
        period_secs: DEFAULT_PERIOD_SECS,
    }
}

fn period_seconds(period: &str) -> u64 {
    match period.to_ascii_lowercase().as_str() {
        "second" | "sec" | "s" => 1,
        "minute" | "min" | "m" => 60,
        "hour" | "hr" | "h" => 3_600,
        "day" | "d" => 86_400,
        _ => DEFAULT_PERIOD_SECS,
    }
}

#[derive(Debug)]
struct WindowEntry {
    window_start: Instant,
    count: u32,
}

pub struct ContactMessageRateLimiter {
    config: ContactMessageRateLimitConfig,
    buckets: Mutex<HashMap<String, WindowEntry>>,
}

impl ContactMessageRateLimiter {
    pub fn new(config: ContactMessageRateLimitConfig) -> Self {
        Self {
            config,
            buckets: Mutex::new(HashMap::new()),
        }
    }

    pub fn from_env() -> Self {
        Self::new(ContactMessageRateLimitConfig::from_env())
    }

    pub fn track_ip(&self, ip: &str) -> RateLimitTrackResult {
        if self.config.limit == 0 {
            return RateLimitTrackResult::Ok;
        }

        let key = format!("contact_message_rate:{}", ip);
        let now = Instant::now();
        let window = Duration::from_secs(self.config.period_secs);
        let mut buckets = self.buckets.lock().expect("contact rate limit mutex");
        let entry = buckets.entry(key).or_insert(WindowEntry {
            window_start: now,
            count: 0,
        });
        if now.duration_since(entry.window_start) >= window {
            entry.window_start = now;
            entry.count = 0;
        }
        entry.count += 1;
        if entry.count > self.config.limit {
            RateLimitTrackResult::RateLimited
        } else {
            RateLimitTrackResult::Ok
        }
    }
}

pub struct ContactMessageRateLimiterAdapter<'a> {
    limiter: &'a ContactMessageRateLimiter,
    remote_ip: String,
}

impl<'a> ContactMessageRateLimiterAdapter<'a> {
    pub fn new(limiter: &'a ContactMessageRateLimiter, remote_ip: impl Into<String>) -> Self {
        Self {
            limiter,
            remote_ip: remote_ip.into(),
        }
    }
}

impl ContactMessageRateLimiterPort for ContactMessageRateLimiterAdapter<'_> {
    fn track(&self) -> RateLimitTrackResult {
        self.limiter.track_ip(&self.remote_ip)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_limit_config_supports_per_minute_and_plain_number() {
        assert_eq!(
            parse_limit_config("10/min"),
            ContactMessageRateLimitConfig {
                limit: 10,
                period_secs: 60,
            }
        );
        assert_eq!(
            parse_limit_config("5"),
            ContactMessageRateLimitConfig {
                limit: 5,
                period_secs: 60,
            }
        );
    }

    #[test]
    fn track_ip_returns_rate_limited_after_limit_exceeded() {
        let limiter = ContactMessageRateLimiter::new(ContactMessageRateLimitConfig {
            limit: 2,
            period_secs: 60,
        });
        assert_eq!(limiter.track_ip("203.0.113.1"), RateLimitTrackResult::Ok);
        assert_eq!(limiter.track_ip("203.0.113.1"), RateLimitTrackResult::Ok);
        assert_eq!(
            limiter.track_ip("203.0.113.1"),
            RateLimitTrackResult::RateLimited
        );
        assert_eq!(limiter.track_ip("203.0.113.2"), RateLimitTrackResult::Ok);
    }
}
