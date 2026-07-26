//! Shared env helpers for integration tests (parallel-safe).

use std::sync::Mutex;

static ENV_TEST_LOCK: Mutex<()> = Mutex::new(());

pub fn restore_env(key: &str, prev: Option<String>) {
    match prev {
        Some(value) => std::env::set_var(key, value),
        None => std::env::remove_var(key),
    }
}

pub fn with_daemon_env<F: FnOnce()>(retries: &str, socket_path: &str, f: F) {
    let _guard = ENV_TEST_LOCK.lock().unwrap_or_else(|e| e.into_inner());
    let prev_retries = std::env::var("AGRR_DAEMON_REQUEST_RETRIES").ok();
    let prev_socket = std::env::var("AGRR_SOCKET_PATH").ok();
    std::env::set_var("AGRR_DAEMON_REQUEST_RETRIES", retries);
    std::env::set_var("AGRR_SOCKET_PATH", socket_path);
    f();
    restore_env("AGRR_DAEMON_REQUEST_RETRIES", prev_retries);
    restore_env("AGRR_SOCKET_PATH", prev_socket);
}
