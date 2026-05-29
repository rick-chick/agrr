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
    #[error("daemon command failed")]
    CommandFailed,
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

    pub fn daemon_running(&self) -> bool {
        self.socket_path.exists()
    }

    /// Send daemon request `{"args": [...]}` (Ruby `bin/agrr_client`).
    pub fn execute_daemon_args(&self, args: &[String]) -> Result<Value, AgrrDaemonError> {
        if !self.daemon_running() {
            return Err(AgrrDaemonError::NotRunning(
                self.socket_path.display().to_string(),
            ));
        }
        let request = serde_json::json!({ "args": args });
        let line = serde_json::to_string(&request).map_err(|e| AgrrDaemonError::Io(
            std::io::Error::new(std::io::ErrorKind::InvalidData, e),
        ))?;

        let rt = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| AgrrDaemonError::Io(std::io::Error::other(e)))?;
        let response = rt.block_on(self.execute_json_command(&line))?;
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
            return Err(AgrrDaemonError::CommandFailed);
        }
        Ok(response)
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
}
