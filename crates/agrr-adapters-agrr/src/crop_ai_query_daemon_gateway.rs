//! Ruby: `Adapters::Agrr::Gateways::CropAiQueryDaemonGateway`

use agrr_domain::crop::dtos::{CropAiCreateFailure, HttpStatus};
use agrr_domain::crop::ports::CropAiQueryGateway;
use serde_json::Value;

use crate::daemon_ai_query::{execute_daemon_json_with_retry, DEFAULT_MAX_RETRIES};
use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};

pub struct CropAiQueryDaemonGateway {
    client: AgrrDaemonClient,
}

impl CropAiQueryDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }

    pub fn new(client: AgrrDaemonClient) -> Self {
        Self { client }
    }

    fn crop_args(crop_name: &str) -> Vec<String> {
        vec![
            "crop".into(),
            "--query".into(),
            crop_name.into(),
            "--json".into(),
        ]
    }
}

impl CropAiQueryGateway for CropAiQueryDaemonGateway {
    fn fetch_crop_json(&self, crop_name: &str) -> Result<Value, CropAiCreateFailure> {
        let args = Self::crop_args(crop_name);
        match execute_daemon_json_with_retry(&self.client, &args, DEFAULT_MAX_RETRIES) {
            Ok(value) => Ok(value),
            Err(e) => Err(map_agrr_error(e)),
        }
    }
}

fn map_agrr_error(err: AgrrDaemonError) -> CropAiCreateFailure {
    let message = match &err {
        AgrrDaemonError::NotRunning(path) => {
            format!("AGRR daemon is not running at {path}")
        }
        AgrrDaemonError::CommandFailed(_) | AgrrDaemonError::Io(_) => err.to_string(),
    };
    let status = if matches!(err, AgrrDaemonError::NotRunning(_)) {
        HttpStatus::ServiceUnavailable
    } else {
        HttpStatus::UnprocessableEntity
    };
    CropAiCreateFailure::new(status, message)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fetch_crop_json_fails_when_daemon_socket_missing() {
        let client = AgrrDaemonClient::new(format!(
            "/tmp/agrr_crop_ai_test_{}.sock",
            std::process::id()
        ));
        let gw = CropAiQueryDaemonGateway::new(client);
        let err = gw.fetch_crop_json("tomato").unwrap_err();
        assert_eq!(err.http_status, HttpStatus::ServiceUnavailable);
        assert!(err.message.contains("not running"));
    }
}
