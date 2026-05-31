//! Ruby: `PlanAllocationCandidatesAgrrDaemonGateway`

use std::path::PathBuf;

use agrr_domain::cultivation_plan::errors::{AllocationExecutionError, AllocationNoCandidatesError};
use agrr_domain::cultivation_plan::gateways::PlanAllocationCandidatesGateway;
use serde_json::Value;
use time::Date;

use crate::agrr_daemon_debug_dump::copy_temp_file_to_debug;
use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_temp_file::write_temp_json_path;

pub struct PlanAllocationCandidatesAgrrDaemonGateway {
    client: AgrrDaemonClient,
}

impl PlanAllocationCandidatesAgrrDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }

    fn write_temp_json(data: &Value, prefix: &str) -> Result<PathBuf, AllocationExecutionError> {
        write_temp_json_path(data, prefix).map_err(|e| AllocationExecutionError::new(e.to_string()))
    }

    fn remove_temp_path(path: &PathBuf) {
        let _ = std::fs::remove_file(path);
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

        let allocation_path = Self::write_temp_json(current_allocation, "candidates_allocation")?;
        let fields_path = Self::write_temp_json(
            &Value::Object(serde_json::Map::from_iter([(
                "fields".into(),
                Value::Array(fields.to_vec()),
            )])),
            "candidates_fields",
        )?;
        let crops_path = Self::write_temp_json(
            &Value::Object(serde_json::Map::from_iter([(
                "crops".into(),
                Value::Array(crops.to_vec()),
            )])),
            "candidates_crops",
        )?;
        let weather_path = Self::write_temp_json(weather_data, "candidates_weather")?;
        let output_path = Self::write_temp_json(&Value::Object(serde_json::Map::new()), "candidates_output")?;

        copy_temp_file_to_debug(&allocation_path, "candidates_allocation");
        copy_temp_file_to_debug(&fields_path, "candidates_fields");
        copy_temp_file_to_debug(&crops_path, "candidates_crops");
        copy_temp_file_to_debug(&weather_path, "candidates_weather");

        let mut args = vec![
            "optimize".into(),
            "candidates".into(),
            "--allocation".into(),
            allocation_path.to_string_lossy().into_owned(),
            "--fields-file".into(),
            fields_path.to_string_lossy().into_owned(),
            "--crops-file".into(),
            crops_path.to_string_lossy().into_owned(),
            "--target-crop".into(),
            target_crop_id,
            "--planning-start".into(),
            planning_start.to_string(),
            "--planning-end".into(),
            planning_end.to_string(),
            "--weather-file".into(),
            weather_path.to_string_lossy().into_owned(),
            "--output".into(),
            output_path.to_string_lossy().into_owned(),
            "--format".into(),
            "json".into(),
        ];

        let rules_path = if let Some(rules) = interaction_rules {
            let rules_path = Self::write_temp_json(rules, "candidates_rules")?;
            copy_temp_file_to_debug(&rules_path, "candidates_rules");
            args.push("--interaction-rules-file".into());
            args.push(rules_path.to_string_lossy().into_owned());
            Some(rules_path)
        } else {
            None
        };

        let _response = self
            .client
            .execute_daemon_args(&args)
            .map_err(map_daemon_error)?;

        copy_temp_file_to_debug(&output_path, "candidates_output");
        let result = parse_candidates_output(&output_path);
        Self::remove_temp_path(&allocation_path);
        Self::remove_temp_path(&fields_path);
        Self::remove_temp_path(&crops_path);
        Self::remove_temp_path(&weather_path);
        if let Some(path) = rules_path {
            Self::remove_temp_path(&path);
        }
        Self::remove_temp_path(&output_path);
        result
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
