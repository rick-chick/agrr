//! Ruby: `Adapters::Agrr::Gateways::PestAiQueryDaemonGateway`

use agrr_domain::pest::interactors::PestAiQueryGateway;
use serde_json::{json, Value};

use crate::daemon_ai_query::{execute_daemon_json_with_retry, DEFAULT_MAX_RETRIES};
use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};

pub struct PestAiQueryDaemonGateway {
    client: AgrrDaemonClient,
}

impl PestAiQueryDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }

    pub fn new(client: AgrrDaemonClient) -> Self {
        Self { client }
    }

    fn pest_args(pest_name: &str, affected_crops: &[Value]) -> Vec<String> {
        let crops_json = serde_json::to_string(affected_crops).unwrap_or_else(|_| "[]".into());
        vec![
            "pest-to-crop".into(),
            "--pest".into(),
            pest_name.into(),
            "--crops".into(),
            crops_json,
            "--language".into(),
            "ja".into(),
        ]
    }
}

impl PestAiQueryGateway for PestAiQueryDaemonGateway {
    fn fetch_pest_json(
        &self,
        pest_name: &str,
        affected_crops: &[Value],
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        let args = Self::pest_args(pest_name, affected_crops);
        match execute_daemon_json_with_retry(&self.client, &args, DEFAULT_MAX_RETRIES) {
            Ok(value) => Ok(value),
            Err(AgrrDaemonError::NotRunning(_)) => Ok(json!({
                "success": false,
                "error": "AGRR daemon is not running",
                "code": "daemon_not_running"
            })),
            Err(e) => Err(e.to_string().into()),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fetch_pest_json_returns_daemon_not_running_payload() {
        let client = AgrrDaemonClient::new(format!(
            "/tmp/agrr_pest_ai_test_{}.sock",
            std::process::id()
        ));
        let gw = PestAiQueryDaemonGateway::new(client);
        let value = gw.fetch_pest_json("aphid", &[]).unwrap();
        assert_eq!(value.get("success"), Some(&json!(false)));
        assert_eq!(value.get("code"), Some(&json!("daemon_not_running")));
    }
}
