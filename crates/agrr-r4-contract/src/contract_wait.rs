//! Shared polling helpers for R4 contract tests (daemon socket readiness).

use std::path::{Path, PathBuf};
use std::sync::Once;
use std::time::Duration;

static ENSURE_DAEMON_ONCE: Once = Once::new();

/// Default agrr daemon socket path (`AGRR_SOCKET_PATH` or `/tmp/agrr.sock`).
pub fn agrr_socket_path() -> PathBuf {
    std::env::var("AGRR_SOCKET_PATH")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/tmp/agrr.sock"))
}

/// Returns true when the agrr daemon socket path exists.
pub fn agrr_daemon_socket_ready() -> bool {
    agrr_socket_path().exists()
}

/// Polls until `path` exists or attempts are exhausted.
pub fn poll_until_path_exists(path: &Path, max_attempts: u32, interval: Duration) -> bool {
    for _ in 0..max_attempts {
        if path.exists() {
            return true;
        }
        std::thread::sleep(interval);
    }
    path.exists()
}

/// Starts agrr daemon once per test process when the binary is available.
pub fn ensure_agrr_daemon_for_contract(agrr_bin: &str, agrr_available: bool) {
    if !agrr_available {
        return;
    }
    ENSURE_DAEMON_ONCE.call_once(|| {
        if agrr_daemon_socket_ready() {
            return;
        }
        let _ = std::process::Command::new(agrr_bin)
            .args(["daemon", "start"])
            .status();
        let socket = agrr_socket_path();
        if !poll_until_path_exists(&socket, 100, Duration::from_millis(50)) {
            eprintln!(
                "warn: agrr daemon socket not ready at {} after polling",
                socket.display()
            );
        }
    });
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::File;
    use std::thread;
    use std::time::{Duration, Instant};

    #[test]
    fn poll_until_path_exists_returns_immediately_when_ready() {
        let dir = std::env::temp_dir().join(format!(
            "agrr-contract-wait-{}",
            std::process::id()
        ));
        let _ = std::fs::create_dir_all(&dir);
        let path = dir.join("ready.sock");
        let _ = File::create(&path);

        let start = Instant::now();
        assert!(poll_until_path_exists(&path, 10, Duration::from_millis(50)));
        assert!(start.elapsed() < Duration::from_millis(100));

        let _ = std::fs::remove_file(&path);
        let _ = std::fs::remove_dir(&dir);
    }

    #[test]
    fn poll_until_path_exists_waits_for_delayed_path() {
        let dir = std::env::temp_dir().join(format!(
            "agrr-contract-wait-delay-{}",
            std::process::id()
        ));
        let _ = std::fs::create_dir_all(&dir);
        let path = dir.join("delayed.sock");
        let delayed = path.clone();

        thread::spawn(move || {
            thread::sleep(Duration::from_millis(80));
            let _ = File::create(delayed);
        });

        assert!(poll_until_path_exists(&path, 20, Duration::from_millis(25)));

        let _ = std::fs::remove_file(&path);
        let _ = std::fs::remove_dir(&dir);
    }
}
