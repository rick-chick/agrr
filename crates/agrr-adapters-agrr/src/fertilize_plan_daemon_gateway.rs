//! Ruby: `Adapters::Agrr::Gateways::FertilizeDaemonGateway#plan`

use agrr_domain::crop::dtos::{CropBlueprintAiFailure, HttpStatus};
use agrr_domain::crop::ports::CropFertilizePlanAiQueryGateway;
use serde_json::Value;

use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_temp_file::{path_string, write_temp_json};

pub struct CropFertilizePlanAiQueryDaemonGateway {
    client: AgrrDaemonClient,
}

impl CropFertilizePlanAiQueryDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }

    pub fn new(client: AgrrDaemonClient) -> Self {
        Self { client }
    }
}

impl CropFertilizePlanAiQueryGateway for CropFertilizePlanAiQueryDaemonGateway {
    fn fetch_fertilize_plan(
        &self,
        crop_requirement: &Value,
        use_harvest_start: bool,
        max_applications: u32,
    ) -> Result<Value, CropBlueprintAiFailure> {
        let crop_file = write_temp_json(crop_requirement, "fertilize_crop")
            .map_err(|e| CropBlueprintAiFailure::new(HttpStatus::UnprocessableEntity, e.to_string()))?;

        let mut args = vec![
            "fertilize".into(),
            "plan".into(),
            "--crop-file".into(),
            path_string(&crop_file),
        ];
        if use_harvest_start {
            args.push("--use-harvest-start".into());
        }
        args.push("--max-applications".into());
        args.push(max_applications.to_string());
        args.push("--json".into());

        match self.client.execute_daemon_args(&args) {
            Ok(value) => Ok(value),
            Err(AgrrDaemonError::NotRunning(path)) => Err(CropBlueprintAiFailure::new(
                HttpStatus::ServiceUnavailable,
                format!("AGRR daemon is not running at {path}"),
            )),
            Err(e) => Err(CropBlueprintAiFailure::new(
                HttpStatus::UnprocessableEntity,
                e.to_string(),
            )),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn fetch_fertilize_plan_fails_when_daemon_socket_missing() {
        let client = AgrrDaemonClient::new(format!(
            "/tmp/agrr_fertilize_plan_test_{}.sock",
            std::process::id()
        ));
        let gw = CropFertilizePlanAiQueryDaemonGateway::new(client);
        let err = gw
            .fetch_fertilize_plan(&json!({"crop": {"name": "tomato"}}), true, 2)
            .unwrap_err();
        assert_eq!(err.http_status, HttpStatus::ServiceUnavailable);
        assert!(err.message.contains("not running"));
    }
}
