//! Shared env helpers for unit tests that exercise daemon-not-running paths.

use std::sync::Mutex;

static ENV_TEST_LOCK: Mutex<()> = Mutex::new(());

pub fn restore_env(key: &str, prev: Option<String>) {
    match prev {
        Some(value) => std::env::set_var(key, value),
        None => std::env::remove_var(key),
    }
}

/// Avoid ~1.4s retry waits when asserting missing-socket / not-running behavior.
pub fn with_single_daemon_request_retry<F: FnOnce()>(f: F) {
    let _guard = ENV_TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let prev_retries = std::env::var("AGRR_DAEMON_REQUEST_RETRIES").ok();
    std::env::set_var("AGRR_DAEMON_REQUEST_RETRIES", "1");
    f();
    restore_env("AGRR_DAEMON_REQUEST_RETRIES", prev_retries);
}
