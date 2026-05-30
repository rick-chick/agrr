//! Ruby: `Adapters::Fertilize::Gateways::FertilizeCliGateway` (daemon via `agrr_client`)

use agrr_domain::fertilize::gateways::FertilizeAiQueryGateway;
use serde_json::{json, Value};

use crate::daemon_ai_query::{execute_daemon_json_with_retry, DEFAULT_MAX_RETRIES};
use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};

pub struct FertilizeAiQueryDaemonGateway {
    client: AgrrDaemonClient,
}

impl FertilizeAiQueryDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }

    pub fn new(client: AgrrDaemonClient) -> Self {
        Self { client }
    }

    fn fetch_from_agrr(&self, name: &str) -> Result<Value, AgrrDaemonError> {
        if name.trim().is_empty() {
            return Err(AgrrDaemonError::CommandFailed(
                "name can't be blank".into(),
            ));
        }
        let args = vec![
            "fertilize".into(),
            "get".into(),
            "--name".into(),
            name.into(),
            "--json".into(),
        ];
        execute_daemon_json_with_retry(&self.client, &args, DEFAULT_MAX_RETRIES)
    }
}

impl FertilizeAiQueryGateway for FertilizeAiQueryDaemonGateway {
    fn fetch_for_create(
        &self,
        name: &str,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        self.fetch_for_update(0, name)
    }

    fn fetch_for_update(
        &self,
        _id: i64,
        name: &str,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        match self.fetch_from_agrr(name) {
            Ok(mut parsed) => {
                normalize_fertilize_payload(&mut parsed);
                Ok(parsed)
            }
            Err(AgrrDaemonError::NotRunning(_)) => Ok(json!({
                "success": false,
                "error": "AGRR daemon is not running",
                "code": "daemon_not_running"
            })),
            Err(e) => Err(e.to_string().into()),
        }
    }
}

/// Ruby `FertilizeCliGateway#fetch_from_agrr` NPK split + fertilize wrapper.
fn normalize_fertilize_payload(parsed: &mut Value) {
    if parsed.get("success") == Some(&Value::Bool(false)) {
        return;
    }

    if parsed.get("fertilize").is_none() {
        let data = std::mem::take(parsed);
        *parsed = json!({ "fertilize": data, "success": true });
    }

    let Some(fertilize) = parsed.get_mut("fertilize").and_then(|v| v.as_object_mut()) else {
        return;
    };
    if fertilize.get("n").is_some() {
        return;
    }
    let Some(npk) = fertilize.get("npk").and_then(|v| v.as_str()) else {
        return;
    };
    let parts: Vec<f64> = npk
        .split('-')
        .filter_map(|s| s.trim().parse().ok())
        .collect();
    if parts.first().copied().filter(|v| *v > 0.0).is_some() {
        fertilize.insert("n".into(), json!(parts[0]));
    }
    if parts.get(1).copied().filter(|v| *v > 0.0).is_some() {
        fertilize.insert("p".into(), json!(parts[1]));
    }
    if parts.get(2).copied().filter(|v| *v > 0.0).is_some() {
        fertilize.insert("k".into(), json!(parts[2]));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalize_splits_npk_into_n_p_k() {
        let mut parsed = json!({
            "success": true,
            "fertilize": { "name": "尿素", "npk": "10-5-3" }
        });
        normalize_fertilize_payload(&mut parsed);
        let f = parsed.get("fertilize").unwrap().as_object().unwrap();
        assert_eq!(f.get("n"), Some(&json!(10.0)));
        assert_eq!(f.get("p"), Some(&json!(5.0)));
        assert_eq!(f.get("k"), Some(&json!(3.0)));
    }

    #[test]
    fn fetch_for_create_returns_daemon_not_running_when_socket_missing() {
        let client = AgrrDaemonClient::new(format!(
            "/tmp/agrr_fert_ai_test_{}.sock",
            std::process::id()
        ));
        let gw = FertilizeAiQueryDaemonGateway::new(client);
        let value = gw.fetch_for_create("尿素").unwrap();
        assert_eq!(value.get("success"), Some(&json!(false)));
        assert_eq!(value.get("code"), Some(&json!("daemon_not_running")));
    }
}
