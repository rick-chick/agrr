//! Ruby: `Adapters::Agrr::Gateways::ScheduleDaemonGateway`

use agrr_domain::crop::dtos::{CropBlueprintAiFailure, HttpStatus};
use agrr_domain::crop::ports::CropScheduleAiQueryGateway;
use serde_json::Value;

use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_temp_file::{path_string, write_temp_json};

pub struct CropScheduleAiQueryDaemonGateway {
    client: AgrrDaemonClient,
}

impl CropScheduleAiQueryDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }

    pub fn new(client: AgrrDaemonClient) -> Self {
        Self { client }
    }
}

impl CropScheduleAiQueryGateway for CropScheduleAiQueryDaemonGateway {
    fn generate_schedule(
        &self,
        crop_name: &str,
        variety: &str,
        stage_requirements: &Value,
        agricultural_tasks: &Value,
    ) -> Result<Value, CropBlueprintAiFailure> {
        let stage_file = write_temp_json(stage_requirements, "stage_requirements")
            .map_err(|e| CropBlueprintAiFailure::new(HttpStatus::UnprocessableEntity, e.to_string()))?;
        let tasks_file = write_temp_json(agricultural_tasks, "agricultural_tasks")
            .map_err(|e| CropBlueprintAiFailure::new(HttpStatus::UnprocessableEntity, e.to_string()))?;

        let args = vec![
            "schedule".into(),
            "--crop-name".into(),
            crop_name.into(),
            "--variety".into(),
            variety.into(),
            "--stage-requirements".into(),
            path_string(&stage_file),
            "--agricultural-tasks".into(),
            path_string(&tasks_file),
            "--json".into(),
        ];

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
    fn generate_schedule_fails_when_daemon_socket_missing() {
        let client = AgrrDaemonClient::new(format!(
            "/tmp/agrr_schedule_test_{}.sock",
            std::process::id()
        ));
        let gw = CropScheduleAiQueryDaemonGateway::new(client);
        let err = gw
            .generate_schedule("tomato", "general", &json!([]), &json!([]))
            .unwrap_err();
        assert_eq!(err.http_status, HttpStatus::ServiceUnavailable);
        assert!(err.message.contains("not running"));
    }
}
