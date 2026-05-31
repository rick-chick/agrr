//! Ruby: `PlanAllocationAdjustAgrrDaemonGateway`


use agrr_domain::cultivation_plan::errors::AdjustExecutionError;
use agrr_domain::cultivation_plan::gateways::PlanAllocationAdjustGateway;
use serde_json::Value;
use std::path::PathBuf;
use time::Date;

use crate::agrr_daemon_debug_dump::copy_temp_file_to_debug;
use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_response::parse_daemon_json_payload;
use crate::daemon_temp_file::write_temp_json_path;

pub struct PlanAllocationAdjustAgrrDaemonGateway {
    client: AgrrDaemonClient,
}

impl PlanAllocationAdjustAgrrDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }

    pub fn new(client: AgrrDaemonClient) -> Self {
        Self { client }
    }

    fn write_temp_json(data: &Value, prefix: &str) -> Result<PathBuf, AdjustExecutionError> {
        write_temp_json_path(data, prefix)
            .map_err(|e| AdjustExecutionError::new(e.to_string()))
    }

    fn remove_temp_path(path: &PathBuf) {
        let _ = std::fs::remove_file(path);
    }
}

impl PlanAllocationAdjustGateway for PlanAllocationAdjustAgrrDaemonGateway {
    fn adjust(
        &self,
        current_allocation: &Value,
        moves: &[Value],
        fields: &[Value],
        crops: &[Value],
        weather_data: &Value,
        planning_start: Date,
        planning_end: Date,
        interaction_rules: Option<&Value>,
        objective: &str,
        max_time: Option<i64>,
        enable_parallel: bool,
    ) -> Result<Value, AdjustExecutionError> {
        let _ = (objective, max_time, enable_parallel);

        let allocation_path = Self::write_temp_json(current_allocation, "current_allocation")?;
        let moves_path = Self::write_temp_json(
            &Value::Object(serde_json::Map::from_iter([(
                "moves".into(),
                Value::Array(moves.to_vec()),
            )])),
            "moves",
        )?;
        let fields_path = Self::write_temp_json(
            &Value::Object(serde_json::Map::from_iter([(
                "fields".into(),
                Value::Array(fields.to_vec()),
            )])),
            "fields",
        )?;
        let crops_path = Self::write_temp_json(
            &Value::Object(serde_json::Map::from_iter([(
                "crops".into(),
                Value::Array(crops.to_vec()),
            )])),
            "crops",
        )?;
        let weather_path = Self::write_temp_json(weather_data, "weather")?;

        copy_temp_file_to_debug(&allocation_path, "adjust_allocation");
        copy_temp_file_to_debug(&moves_path, "adjust_moves");
        copy_temp_file_to_debug(&fields_path, "adjust_fields");
        copy_temp_file_to_debug(&crops_path, "adjust_crops");
        copy_temp_file_to_debug(&weather_path, "adjust_weather");

        let mut args: Vec<String> = vec![
            "optimize".into(),
            "adjust".into(),
            "--current-allocation".into(),
            allocation_path.to_string_lossy().into_owned(),
            "--moves".into(),
            moves_path.to_string_lossy().into_owned(),
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
            "--format".into(),
            "json".into(),
        ];

        let rules_path = if let Some(rules) = interaction_rules {
            let rules_path = Self::write_temp_json(rules, "interaction_rules")?;
            copy_temp_file_to_debug(&rules_path, "adjust_rules");
            args.push("--interaction-rules-file".into());
            args.push(rules_path.to_string_lossy().into_owned());
            Some(rules_path)
        } else {
            None
        };

        let wrapper = self
            .client
            .execute_daemon_args(&args)
            .map_err(map_daemon_error)?;
        let payload = parse_daemon_json_payload(&wrapper).map_err(map_daemon_error)?;

        let result = parse_adjust_result(&payload);
        Self::remove_temp_path(&allocation_path);
        Self::remove_temp_path(&moves_path);
        Self::remove_temp_path(&fields_path);
        Self::remove_temp_path(&crops_path);
        Self::remove_temp_path(&weather_path);
        if let Some(path) = rules_path {
            Self::remove_temp_path(&path);
        }
        result
    }
}

fn map_daemon_error(err: AgrrDaemonError) -> AdjustExecutionError {
    AdjustExecutionError::new(err.to_string())
}

fn parse_adjust_result(raw: &Value) -> Result<Value, AdjustExecutionError> {
    let optimization = raw.get("optimization_result").ok_or_else(|| {
        AdjustExecutionError::new("missing optimization_result in agrr response")
    })?;
    let summary = raw.get("summary").cloned();

    let field_schedules: Vec<Value> = optimization
        .get("field_schedules")
        .and_then(|v| v.as_array())
        .map(|schedules| {
            schedules
                .iter()
                .map(|fs| {
                    let field_data = fs.get("field").cloned().unwrap_or(Value::Null);
                    let field_id = field_data
                        .get("field_id")
                        .or_else(|| fs.get("field_id"))
                        .cloned()
                        .unwrap_or(Value::Null);
                    let field_name = field_data
                        .get("name")
                        .or_else(|| fs.get("field_name"))
                        .cloned()
                        .unwrap_or(Value::Null);
                    let allocations: Vec<Value> = fs
                        .get("allocations")
                        .and_then(|v| v.as_array())
                        .map(|allocs| {
                            allocs
                                .iter()
                                .map(|alloc| {
                                    let crop_data = alloc.get("crop").cloned().unwrap_or(Value::Null);
                                    let mut merged = alloc.as_object().cloned().unwrap_or_default();
                                    merged.remove("crop");
                                    if let Some(crop_obj) = crop_data.as_object() {
                                        for (k, v) in crop_obj {
                                            merged.insert(k.clone(), v.clone());
                                        }
                                    }
                                    Value::Object(merged)
                                })
                                .collect()
                        })
                        .unwrap_or_default();
                    serde_json::json!({
                        "field_id": field_id,
                        "field_name": field_name,
                        "allocations": allocations
                    })
                })
                .collect()
        })
        .unwrap_or_default();

    Ok(serde_json::json!({
        "optimization_id": optimization.get("optimization_id"),
        "algorithm_used": optimization.get("algorithm_used"),
        "is_optimal": optimization.get("is_optimal"),
        "optimization_time": optimization.get("optimization_time"),
        "total_cost": optimization.get("total_cost"),
        "total_revenue": optimization.get("total_revenue"),
        "total_profit": optimization.get("total_profit"),
        "field_schedules": field_schedules,
        "crop_areas": optimization.get("crop_areas"),
        "summary": summary,
        "raw": raw
    }))
}
