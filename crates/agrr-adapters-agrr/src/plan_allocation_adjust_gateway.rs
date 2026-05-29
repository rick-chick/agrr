//! Ruby: `PlanAllocationAdjustAgrrDaemonGateway`

use std::path::PathBuf;

use agrr_domain::cultivation_plan::errors::AdjustExecutionError;
use agrr_domain::cultivation_plan::gateways::PlanAllocationAdjustGateway;
use serde_json::Value;
use tempfile::NamedTempFile;
use time::Date;

use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};

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

    fn write_temp_json(data: &Value, prefix: &str) -> Result<NamedTempFile, AdjustExecutionError> {
        let file = NamedTempFile::with_prefix(prefix).map_err(|e| {
            AdjustExecutionError::new(format!("temp file: {e}"))
        })?;
        std::io::Write::write_all(
            &mut file.as_file(),
            serde_json::to_string(data)
                .map_err(|e| AdjustExecutionError::new(e.to_string()))?
                .as_bytes(),
        )
        .map_err(|e| AdjustExecutionError::new(e.to_string()))?;
        file.as_file()
            .sync_all()
            .map_err(|e| AdjustExecutionError::new(e.to_string()))?;
        Ok(file)
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

        let allocation_file = Self::write_temp_json(current_allocation, "current_allocation")?;
        let moves_file = Self::write_temp_json(&Value::Object(serde_json::Map::from_iter([(
            "moves".into(),
            Value::Array(moves.to_vec()),
        )])), "moves")?;
        let fields_file = Self::write_temp_json(
            &Value::Object(serde_json::Map::from_iter([(
                "fields".into(),
                Value::Array(fields.to_vec()),
            )])),
            "fields",
        )?;
        let crops_file = Self::write_temp_json(
            &Value::Object(serde_json::Map::from_iter([(
                "crops".into(),
                Value::Array(crops.to_vec()),
            )])),
            "crops",
        )?;
        let weather_file = Self::write_temp_json(weather_data, "weather")?;

        let allocation_path = allocation_file.path().to_string_lossy().into_owned();
        let moves_path = moves_file.path().to_string_lossy().into_owned();
        let fields_path = fields_file.path().to_string_lossy().into_owned();
        let crops_path = crops_file.path().to_string_lossy().into_owned();
        let weather_path = weather_file.path().to_string_lossy().into_owned();

        let mut args = vec![
            "optimize".into(),
            "adjust".into(),
            "--current-allocation".into(),
            allocation_path,
            "--moves".into(),
            moves_path,
            "--fields-file".into(),
            fields_path,
            "--crops-file".into(),
            crops_path,
            "--planning-start".into(),
            planning_start.to_string(),
            "--planning-end".into(),
            planning_end.to_string(),
            "--weather-file".into(),
            weather_path,
            "--format".into(),
            "json".into(),
        ];

        let rules_file;
        let rules_path: Option<String>;
        if let Some(rules) = interaction_rules {
            rules_file = Self::write_temp_json(rules, "interaction_rules")?;
            rules_path = Some(rules_file.path().to_string_lossy().into_owned());
            args.push("--interaction-rules-file".into());
            args.push(rules_path.clone().unwrap());
        } else {
            rules_path = None;
        }

        let response = self
            .client
            .execute_daemon_args(&args)
            .map_err(map_daemon_error)?;

        parse_adjust_result(&response)
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
