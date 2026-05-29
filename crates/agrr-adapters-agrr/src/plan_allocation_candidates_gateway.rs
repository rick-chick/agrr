//! Ruby: `PlanAllocationCandidatesAgrrDaemonGateway`

use std::path::PathBuf;

use agrr_domain::cultivation_plan::errors::{AllocationExecutionError, AllocationNoCandidatesError};
use agrr_domain::cultivation_plan::gateways::PlanAllocationCandidatesGateway;
use serde_json::Value;
use tempfile::NamedTempFile;
use time::Date;

use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};

pub struct PlanAllocationCandidatesAgrrDaemonGateway {
    client: AgrrDaemonClient,
}

impl PlanAllocationCandidatesAgrrDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }

    fn write_temp_json(data: &Value, prefix: &str) -> Result<NamedTempFile, AllocationExecutionError> {
        let file = NamedTempFile::with_prefix(prefix).map_err(|e| {
            AllocationExecutionError::new(format!("temp file: {e}"))
        })?;
        std::io::Write::write_all(
            &mut file.as_file(),
            serde_json::to_string(data)
                .map_err(|e| AllocationExecutionError::new(e.to_string()))?
                .as_bytes(),
        )
        .map_err(|e| AllocationExecutionError::new(e.to_string()))?;
        file.as_file()
            .sync_all()
            .map_err(|e| AllocationExecutionError::new(e.to_string()))?;
        Ok(file)
    }
}

impl PlanAllocationCandidatesGateway for PlanAllocationCandidatesAgrrDaemonGateway {
    fn candidates(
        &self,
        current_allocation: &Value,
        fields: &[Value],
        crops: &[Value],
        target_crop: &Value,
        weather_data: &Value,
        planning_start: Date,
        planning_end: Date,
        interaction_rules: Option<&Value>,
    ) -> Result<Vec<Value>, Box<dyn std::error::Error + Send + Sync>> {
        let target_crop_id = target_crop
            .as_str()
            .map(|s| s.to_string())
            .or_else(|| target_crop.as_i64().map(|n| n.to_string()))
            .ok_or_else(|| AllocationExecutionError::new("invalid target_crop"))?;

        let allocation_file = Self::write_temp_json(current_allocation, "candidates_allocation")?;
        let fields_file = Self::write_temp_json(
            &Value::Object(serde_json::Map::from_iter([(
                "fields".into(),
                Value::Array(fields.to_vec()),
            )])),
            "candidates_fields",
        )?;
        let crops_file = Self::write_temp_json(
            &Value::Object(serde_json::Map::from_iter([(
                "crops".into(),
                Value::Array(crops.to_vec()),
            )])),
            "candidates_crops",
        )?;
        let weather_file = Self::write_temp_json(weather_data, "candidates_weather")?;
        let output_file = tempfile::NamedTempFile::with_prefix("candidates_output").map_err(|e| {
            AllocationExecutionError::new(e.to_string())
        })?;
        let output_path: PathBuf = output_file.path().to_path_buf();

        let mut args = vec![
            "optimize".into(),
            "candidates".into(),
            "--allocation".into(),
            allocation_file.path().to_string_lossy().into_owned(),
            "--fields-file".into(),
            fields_file.path().to_string_lossy().into_owned(),
            "--crops-file".into(),
            crops_file.path().to_string_lossy().into_owned(),
            "--target-crop".into(),
            target_crop_id,
            "--planning-start".into(),
            planning_start.to_string(),
            "--planning-end".into(),
            planning_end.to_string(),
            "--weather-file".into(),
            weather_file.path().to_string_lossy().into_owned(),
            "--output".into(),
            output_path.to_string_lossy().into_owned(),
            "--format".into(),
            "json".into(),
        ];

        if let Some(rules) = interaction_rules {
            let rules_file = Self::write_temp_json(rules, "candidates_rules")?;
            args.push("--interaction-rules-file".into());
            args.push(rules_file.path().to_string_lossy().into_owned());
        }

        let _response = self
            .client
            .execute_daemon_args(&args)
            .map_err(map_daemon_error)?;

        parse_candidates_output(&output_path)
    }
}

fn map_daemon_error(err: AgrrDaemonError) -> AllocationExecutionError {
    AllocationExecutionError::new(err.to_string())
}

fn parse_candidates_output(
    output_path: &PathBuf,
) -> Result<Vec<Value>, Box<dyn std::error::Error + Send + Sync>> {
    let raw = std::fs::read_to_string(output_path).unwrap_or_default();
    if raw.trim().is_empty() {
        return Err(Box::new(AllocationNoCandidatesError::new(
            "no candidates output",
        )));
    }
    let parsed: Value = serde_json::from_str(&raw).map_err(|e| {
        AllocationExecutionError::new(format!("parse candidates output: {e}"))
    })?;
    let list = match parsed {
        Value::Object(ref obj) => obj
            .get("candidates")
            .and_then(|v| v.as_array())
            .cloned()
            .unwrap_or_default(),
        Value::Array(arr) => arr,
        _ => Vec::new(),
    };
    if list.is_empty() {
        return Err(Box::new(AllocationNoCandidatesError::new(
            "no valid allocation candidates",
        )));
    }
    Ok(list)
}
