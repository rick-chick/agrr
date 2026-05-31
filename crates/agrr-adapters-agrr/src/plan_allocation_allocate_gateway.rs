//! Ruby: `PlanAllocationAllocateAgrrDaemonGateway` / `AllocationDaemonGateway`
//!
//! Always calls the agrr daemon (Rails parity — no mock allocation path).

use std::path::PathBuf;

use agrr_domain::cultivation_plan::errors::{AllocationExecutionError, AllocationNoCandidatesError};
use agrr_domain::cultivation_plan::gateways::PlanAllocationAllocateGateway;
use agrr_domain::cultivation_plan::policies::cultivation_plan_allocate_allocation_policy;
use agrr_domain::cultivation_plan::policies::cultivation_plan_optimization_complete_policy;
use serde_json::{json, Value};
use time::Date;

use crate::agrr_daemon_debug_dump::copy_temp_file_to_debug;
use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_response::parse_daemon_json_payload;
use crate::daemon_temp_file::write_temp_json_path;

pub struct PlanAllocationAllocateAgrrDaemonGateway {
    client: AgrrDaemonClient,
}

impl PlanAllocationAllocateAgrrDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }

    pub fn new(client: AgrrDaemonClient) -> Self {
        Self { client }
    }

    fn write_temp_json(data: &Value, prefix: &str) -> Result<PathBuf, AllocationExecutionError> {
        write_temp_json_path(data, prefix)
            .map_err(|e| AllocationExecutionError::new(e.to_string()))
    }

    fn remove_temp_path(path: &PathBuf) {
        let _ = std::fs::remove_file(path);
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
        let fields_path = Self::write_temp_json(
            &json!({ "fields": fields }),
            "allocate_fields",
        )?;
        let crops_path = Self::write_temp_json(&json!({ "crops": crops }), "allocate_crops")?;
        let weather_path = Self::write_temp_json(weather_data, "allocate_weather")?;

        copy_temp_file_to_debug(&fields_path, "allocation_fields");
        copy_temp_file_to_debug(&crops_path, "allocation_crops");
        copy_temp_file_to_debug(&weather_path, "allocation_weather");

        let mut args = vec![
            "optimize".into(),
            "allocate".into(),
            "--fields-file".into(),
            fields_path.to_string_lossy().into_owned(),
            "--crops-file".into(),
            crops_path.to_string_lossy().into_owned(),
            "--planning-start".into(),
            planning_start.to_string(),
            "--planning-end".into(),
            planning_end.to_string(),
            "--weather-file".into(),
            weather_path.to_string_lossy().into_owned(),
            "--objective".into(),
            objective.into(),
            "--format".into(),
            "json".into(),
        ];

        let rules_path = if let Some(rules) = interaction_rules {
            let rules_path = Self::write_temp_json(rules, "allocate_rules")?;
            copy_temp_file_to_debug(&rules_path, "allocation_rules");
            args.push("--interaction-rules-file".into());
            args.push(rules_path.to_string_lossy().into_owned());
            Some(rules_path)
        } else {
            None
        };

        if let Some(max_time) = max_time {
            args.push("--max-time".into());
            args.push(max_time.to_string());
        }
        if enable_parallel {
            args.push("--enable-parallel".into());
        }

        let wrapper = self
            .client
            .execute_daemon_args(&args)
            .map_err(map_daemon_error)?;
        let value = parse_daemon_json_payload(&wrapper).map_err(map_daemon_error)?;
        let result =
            parse_allocate_result(&value).map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>);

        Self::remove_temp_path(&fields_path);
        Self::remove_temp_path(&crops_path);
        Self::remove_temp_path(&weather_path);
        if let Some(path) = rules_path {
            Self::remove_temp_path(&path);
        }

        result
    }
}

fn parse_allocate_result(raw: &Value) -> Result<Value, AllocationNoCandidatesError> {
    let normalized = if let Some(schedules) = raw.get("field_schedules").and_then(|v| v.as_array()) {
        if schedules.is_empty() {
            return Err(AllocationNoCandidatesError::new(
                "allocation returned empty field_schedules",
            ));
        }
        raw.clone()
    } else if let Some(optimization) = raw.get("optimization_result") {
        let field_schedules = optimization
            .get("field_schedules")
            .cloned()
            .unwrap_or_else(|| serde_json::json!([]));
        if !cultivation_plan_optimization_complete_policy::allocation_has_field_schedules(
            &serde_json::json!({ "field_schedules": &field_schedules }),
        ) {
            return Err(AllocationNoCandidatesError::new(
                "allocation optimization_result has empty field_schedules",
            ));
        }
        serde_json::json!({
            "field_schedules": field_schedules,
            "optimization_result": optimization,
            "summary": raw.get("summary"),
        })
    } else if raw.is_object() {
        return Err(AllocationNoCandidatesError::new(
            "allocation result has no field_schedules",
        ));
    } else {
        return Err(AllocationNoCandidatesError::new(
            "allocation result empty",
        ));
    };

    if !cultivation_plan_allocate_allocation_policy::allocation_result_persistable(&normalized) {
        return Err(AllocationNoCandidatesError::new(
            "allocation result has no persistable allocations",
        ));
    }

    Ok(normalized)
}

fn map_daemon_error(err: AgrrDaemonError) -> AllocationExecutionError {
    AllocationExecutionError::new(err.to_string())
}
