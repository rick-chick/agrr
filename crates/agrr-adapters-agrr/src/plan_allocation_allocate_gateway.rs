//! Ruby: `PlanAllocationAllocateAgrrDaemonGateway` / `AllocationDaemonGateway`

use std::path::PathBuf;

use agrr_domain::cultivation_plan::errors::{AllocationExecutionError, AllocationNoCandidatesError};
use agrr_domain::cultivation_plan::gateways::PlanAllocationAllocateGateway;
use serde_json::Value;
use tempfile::NamedTempFile;
use time::Date;

use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};

pub struct PlanAllocationAllocateAgrrDaemonGateway {
    client: AgrrDaemonClient,
}

impl PlanAllocationAllocateAgrrDaemonGateway {
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

impl PlanAllocationAllocateGateway for PlanAllocationAllocateAgrrDaemonGateway {
    fn allocate(
        &self,
        fields: &[Value],
        crops: &[Value],
        weather_data: &Value,
        planning_start: Date,
        planning_end: Date,
        interaction_rules: Option<&Value>,
        objective: &str,
        max_time: Option<i64>,
        enable_parallel: bool,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        let fields_file = Self::write_temp_json(
            &Value::Object(serde_json::Map::from_iter([(
                "fields".into(),
                Value::Array(fields.to_vec()),
            )])),
            "allocate_fields",
        )?;
        let crops_file = Self::write_temp_json(
            &Value::Object(serde_json::Map::from_iter([(
                "crops".into(),
                Value::Array(crops.to_vec()),
            )])),
            "allocate_crops",
        )?;
        let weather_file = Self::write_temp_json(weather_data, "allocate_weather")?;
        let output_file = tempfile::NamedTempFile::with_prefix("allocate_output").map_err(|e| {
            AllocationExecutionError::new(e.to_string())
        })?;
        let output_path: PathBuf = output_file.path().to_path_buf();

        let mut args = vec![
            "optimize".into(),
            "allocate".into(),
            "--fields-file".into(),
            fields_file.path().to_string_lossy().into_owned(),
            "--crops-file".into(),
            crops_file.path().to_string_lossy().into_owned(),
            "--planning-start".into(),
            planning_start.to_string(),
            "--planning-end".into(),
            planning_end.to_string(),
            "--weather-file".into(),
            weather_file.path().to_string_lossy().into_owned(),
            "--objective".into(),
            objective.into(),
            "--output".into(),
            output_path.to_string_lossy().into_owned(),
            "--format".into(),
            "json".into(),
        ];

        if let Some(rules) = interaction_rules {
            let rules_file = Self::write_temp_json(rules, "allocate_rules")?;
            args.push("--interaction-rules-file".into());
            args.push(rules_file.path().to_string_lossy().into_owned());
        }
        if let Some(max_time) = max_time {
            args.push("--max-time".into());
            args.push(max_time.to_string());
        }
        if enable_parallel {
            args.push("--enable-parallel".into());
        }

        let _response = self
            .client
            .execute_daemon_args(&args)
            .map_err(map_daemon_error)?;

        let text = std::fs::read_to_string(&output_path).map_err(|e| {
            AllocationExecutionError::new(e.to_string())
        })?;
        let value: Value = serde_json::from_str(&text).map_err(|e| {
            AllocationExecutionError::new(e.to_string())
        })?;
        if value.get("field_schedules").is_some() {
            return Ok(value);
        }
        Err(Box::new(AllocationNoCandidatesError::new(
            "allocation result empty",
        )))
    }
}

fn map_daemon_error(err: AgrrDaemonError) -> AllocationExecutionError {
    AllocationExecutionError::new(err.to_string())
}
