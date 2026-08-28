//! Stable user-facing mapping when the agrr Python daemon is not reachable.
//!
//! Boot intentionally does not wait for daemon readiness (`scripts/db_bootstrap_common.sh`);
//! request-time connect retries live in [`AgrrDaemonClient`](crate::daemon_client::AgrrDaemonClient).
//!
//! ## Monitoring / alerting (ops)
//!
//! - **Readiness**: `GET /api/v1/ready` returns 503 when `USE_AGRR_DAEMON=true` and the socket
//!   does not accept connections (`AgrrDaemonClient::daemon_running`).
//! - **Detailed status**: `GET /api/v1/backdoor/status` exposes `daemon.running` and
//!   `service_available` for on-call dashboards.
//! - **Alert when**: `USE_AGRR_DAEMON=true` and readiness or backdoor `service_available` is false
//!   for sustained intervals (e.g. Cloud Run readiness probe failures).
//! - **Tuning**: `AGRR_DAEMON_REQUEST_RETRIES` (default 15 × 100 ms) absorbs brief boot gaps.

use std::error::Error;

use thiserror::Error;

use crate::daemon_client::AgrrDaemonError;

/// Machine-readable code shared across gateways and domain errors.
const DAEMON_UNAVAILABLE_CODE: &str = "daemon_unavailable";

/// Stable error string stored in logs / chain step errors (no socket path).
pub const DAEMON_UNAVAILABLE_MESSAGE: &str = "daemon_unavailable";

#[derive(Debug, Error, Clone, PartialEq, Eq)]
#[error("{DAEMON_UNAVAILABLE_MESSAGE}")]
pub struct DaemonUnavailableError;

pub fn use_agrr_daemon_enabled() -> bool {
    std::env::var("USE_AGRR_DAEMON").as_deref() == Ok("true")
}

pub fn is_daemon_not_running(err: &AgrrDaemonError) -> bool {
    matches!(err, AgrrDaemonError::NotRunning(_))
}

pub fn map_agrr_daemon_error(err: AgrrDaemonError) -> Box<dyn Error + Send + Sync> {
    if is_daemon_not_running(&err) {
        Box::new(DaemonUnavailableError)
    } else {
        Box::new(err)
    }
}

/// Stable message for gateways that surface `String` errors (optimization chain steps).
pub fn agrr_daemon_error_message(err: AgrrDaemonError) -> String {
    if is_daemon_not_running(&err) {
        DAEMON_UNAVAILABLE_MESSAGE.to_string()
    } else {
        err.to_string()
    }
}

/// Detects daemon-outage messages from adapters or legacy gateways.
pub fn is_daemon_unavailable_message(message: &str) -> bool {
    message == DAEMON_UNAVAILABLE_MESSAGE
        || message.contains("agrr daemon is not running")
        || message.contains(DAEMON_UNAVAILABLE_CODE)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn map_not_running_to_daemon_unavailable_error() {
        let err = map_agrr_daemon_error(AgrrDaemonError::NotRunning("/tmp/x.sock".into()));
        assert!(err.downcast_ref::<DaemonUnavailableError>().is_some());
        assert_eq!(err.to_string(), DAEMON_UNAVAILABLE_MESSAGE);
    }

    #[test]
    fn map_io_error_preserves_variant() {
        let io_err = std::io::Error::new(std::io::ErrorKind::NotFound, "missing");
        let err = map_agrr_daemon_error(AgrrDaemonError::Io(io_err));
        assert!(err.downcast_ref::<AgrrDaemonError>().is_some());
    }

    #[test]
    fn is_daemon_unavailable_message_detects_legacy_and_stable_forms() {
        assert!(is_daemon_unavailable_message(DAEMON_UNAVAILABLE_MESSAGE));
        assert!(is_daemon_unavailable_message(
            "agrr daemon is not running at /tmp/agrr.sock"
        ));
        assert!(!is_daemon_unavailable_message("count failed"));
    }

    #[test]
    fn use_agrr_daemon_enabled_reads_env() {
        let prev = std::env::var("USE_AGRR_DAEMON").ok();
        std::env::set_var("USE_AGRR_DAEMON", "true");
        assert!(use_agrr_daemon_enabled());
        match prev {
            Some(v) => std::env::set_var("USE_AGRR_DAEMON", v),
            None => std::env::remove_var("USE_AGRR_DAEMON"),
        }
    }
}
