use std::path::{Path, PathBuf};
use serde_json::Value;
use thiserror::Error;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::UnixStream;

#[derive(Debug, Error)]
pub enum AgrrDaemonError {
    #[error("agrr daemon is not running at {0}")]
    NotRunning(String),
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    #[error("daemon command failed: {0}")]
    CommandFailed(String),
}

/// Minimal Unix-socket client matching Ruby `DaemonClient` surface for P6.
pub struct AgrrDaemonClient {
    socket_path: PathBuf,
}

impl AgrrDaemonClient {
    pub fn from_env() -> Self {
        let socket_path = std::env::var("AGRR_SOCKET_PATH")
            .map(PathBuf::from)
            .unwrap_or_else(|_| PathBuf::from("/tmp/agrr.sock"));
        Self { socket_path }
    }

    pub fn new(socket_path: impl AsRef<Path>) -> Self {
        Self {
            socket_path: socket_path.as_ref().to_path_buf(),
        }
    }

    /// True only when the Unix socket accepts a connection (not merely when the path exists).
    ///
    /// Boot starts the daemon without readiness wait; a leftover socket file from a crashed
    /// instance must not be treated as healthy. See `execute_daemon_args` for request-time retries.
    pub fn daemon_running(&self) -> bool {
        socket_accepts_connection(&self.socket_path)
    }

    /// Send daemon request `{"args": [...]}` (Ruby `bin/agrr_client`).
    ///
    /// Retries on connect/`NotRunning` at request time only. Boot intentionally does not wait
    /// for daemon readiness so HTTP can bind in parallel; brief retries here absorb that gap.
    pub fn execute_daemon_args(&self, args: &[String]) -> Result<Value, AgrrDaemonError> {
        let request_retries = request_connect_retries();
        const REQUEST_RETRY_MS: u64 = 100;

        let request = serde_json::json!({ "args": args });
        let line = serde_json::to_string(&request).map_err(|e| AgrrDaemonError::Io(
            std::io::Error::new(std::io::ErrorKind::InvalidData, e),
        ))?;

        let mut last_err = AgrrDaemonError::NotRunning(self.socket_path.display().to_string());
        for attempt in 0..request_retries {
            match self.execute_daemon_args_once(&line) {
                Ok(value) => return Ok(value),
                Err(err) if request_time_recoverable(&err) && attempt + 1 < request_retries => {
                    last_err = err;
                    std::thread::sleep(std::time::Duration::from_millis(REQUEST_RETRY_MS));
                }
                Err(err) => return Err(err),
            }
        }
        Err(last_err)
    }

    fn execute_daemon_args_once(&self, line: &str) -> Result<Value, AgrrDaemonError> {
        if !self.daemon_running() {
            return Err(AgrrDaemonError::NotRunning(
                self.socket_path.display().to_string(),
            ));
        }

        let response = if let Ok(handle) = tokio::runtime::Handle::try_current() {
            tokio::task::block_in_place(|| handle.block_on(self.execute_json_command(line)))
        } else {
            let rt = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .map_err(|e| AgrrDaemonError::Io(std::io::Error::other(e)))?;
            rt.block_on(self.execute_json_command(line))
        }?;
        let value: Value = serde_json::from_str(&response).map_err(|e| {
            AgrrDaemonError::Io(std::io::Error::new(std::io::ErrorKind::InvalidData, e))
        })?;
        Ok(value)
    }

    pub async fn execute_json_command(&self, line: &str) -> Result<String, AgrrDaemonError> {
        if !self.daemon_running() {
            return Err(AgrrDaemonError::NotRunning(
                self.socket_path.display().to_string(),
            ));
        }
        let mut stream = UnixStream::connect(&self.socket_path).await?;
        stream.write_all(line.as_bytes()).await?;
        stream.write_all(b"\n").await?;
        let mut buf = Vec::new();
        stream.read_to_end(&mut buf).await?;
        let response = String::from_utf8_lossy(&buf).into_owned();
        if response.trim().is_empty() {
            return Err(AgrrDaemonError::CommandFailed(
                "empty response from daemon".into(),
            ));
        }
        Ok(response)
    }
}

fn request_connect_retries() -> u32 {
    std::env::var("AGRR_DAEMON_REQUEST_RETRIES")
        .ok()
        .and_then(|v| v.parse().ok())
        .unwrap_or(15)
}

fn socket_accepts_connection(path: &Path) -> bool {
    #[cfg(unix)]
    {
        use std::os::unix::net::UnixStream;
        UnixStream::connect(path).is_ok()
    }
    #[cfg(not(unix))]
    {
        let _ = path;
        false
    }
}

fn request_time_recoverable(error: &AgrrDaemonError) -> bool {
    match error {
        AgrrDaemonError::NotRunning(_) => true,
        AgrrDaemonError::Io(io_err) => matches!(
            io_err.kind(),
            std::io::ErrorKind::NotFound
                | std::io::ErrorKind::ConnectionRefused
                | std::io::ErrorKind::ConnectionReset
                | std::io::ErrorKind::BrokenPipe
        ),
        AgrrDaemonError::CommandFailed(_) => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn not_running_without_socket() {
        let client = AgrrDaemonClient::new("/tmp/agrr_test_missing.sock");
        assert!(!client.daemon_running());
    }

    #[test]
    fn not_running_when_socket_path_exists_but_does_not_accept_connections() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("agrr.sock");
        std::fs::write(&path, b"stale socket file").expect("write");
        let client = AgrrDaemonClient::new(&path);
        assert!(!client.daemon_running());
    }

    #[test]
    fn request_connect_retries_defaults_to_fifteen() {
        std::env::remove_var("AGRR_DAEMON_REQUEST_RETRIES");
        assert_eq!(request_connect_retries(), 15);
    }

    #[test]
    fn request_time_recoverable_matches_not_running_and_connection_errors() {
        assert!(request_time_recoverable(&AgrrDaemonError::NotRunning(
            "/tmp/agrr.sock".into()
        )));
        assert!(request_time_recoverable(&AgrrDaemonError::Io(
            std::io::Error::from(std::io::ErrorKind::ConnectionRefused)
        )));
        assert!(!request_time_recoverable(&AgrrDaemonError::CommandFailed(
            "exit 1".into()
        )));
    }
}
