//! Shared retry / transient-error handling for agrr AI query daemon gateways.
//! Ruby parity: `CropAiQueryDaemonGateway`, `PestAiQueryDaemonGateway`, `FertilizeCliGateway`.

use std::thread;
use std::time::Duration;

use serde_json::Value;

use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_response::parse_daemon_json_payload;

pub const DEFAULT_MAX_RETRIES: u32 = 3;

pub fn is_transient_error(message: &str) -> bool {
    message.contains("decompressing")
        || message.contains("Connection")
        || message.contains("timeout")
        || message.contains("Network")
}

/// Execute daemon CLI args with retries on transient failures.
pub fn execute_daemon_json_with_retry(
    client: &AgrrDaemonClient,
    args: &[String],
    max_retries: u32,
) -> Result<Value, AgrrDaemonError> {
    let mut attempt = 0u32;
    let mut last_error: Option<AgrrDaemonError> = None;

    while attempt < max_retries {
        attempt += 1;
        match client.execute_daemon_args(args) {
            Ok(wrapper) => match parse_daemon_json_payload(&wrapper) {
                Ok(payload) => return Ok(payload),
                Err(e) => {
                    let msg = e.to_string();
                    if is_transient_error(&msg) && attempt < max_retries {
                        thread::sleep(backoff_duration(attempt));
                        last_error = Some(e);
                        continue;
                    }
                    return Err(e);
                }
            },
            Err(e @ AgrrDaemonError::NotRunning(_)) => return Err(e),
            Err(e @ AgrrDaemonError::CommandFailed(_)) => {
                let msg = e.to_string();
                if is_transient_error(&msg) && attempt < max_retries {
                    thread::sleep(backoff_duration(attempt));
                    last_error = Some(e);
                    continue;
                }
                return Err(e);
            }
            Err(e @ AgrrDaemonError::Io(_)) => {
                if attempt < max_retries {
                    thread::sleep(backoff_duration(attempt));
                    last_error = Some(e);
                    continue;
                }
                return Err(e);
            }
        }
    }

    Err(last_error.unwrap_or_else(|| {
        AgrrDaemonError::CommandFailed(format!(
            "failed after {max_retries} daemon query attempts"
        ))
    }))
}

fn backoff_duration(attempt: u32) -> Duration {
    Duration::from_secs(2u64.saturating_pow(attempt))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn transient_error_detection_matches_ruby_keywords() {
        assert!(is_transient_error("Connection reset"));
        assert!(is_transient_error("Network unreachable"));
        assert!(is_transient_error("timeout while waiting"));
        assert!(!is_transient_error("invalid crop name"));
    }

    #[test]
    fn backoff_duration_doubles_each_attempt() {
        assert_eq!(backoff_duration(1), Duration::from_secs(2));
        assert_eq!(backoff_duration(2), Duration::from_secs(4));
    }
}
