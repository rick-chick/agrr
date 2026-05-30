//! Ruby: `PlanAllocationAllocateAgrrDaemonGateway` / `AllocationDaemonGateway`

use agrr_domain::cultivation_plan::errors::{AllocationExecutionError, AllocationNoCandidatesError};
use agrr_domain::cultivation_plan::gateways::PlanAllocationAllocateGateway;
use agrr_domain::cultivation_plan::policies::cultivation_plan_optimization_complete_policy;
use serde_json::{json, Value};
use time::Date;

use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_response::parse_daemon_json_payload;
use crate::daemon_temp_file::{path_string, write_temp_json};

pub struct PlanAllocationAllocateAgrrDaemonGateway {
    client: AgrrDaemonClient,
}

impl PlanAllocationAllocateAgrrDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
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
        if std::env::var("AGRR_USE_MOCK").as_deref() != Ok("false") {
            let mock = mock_allocate_result(fields, crops, planning_start, planning_end);
            if !cultivation_plan_optimization_complete_policy::allocation_has_field_schedules(&mock)
            {
                return Err(Box::new(AllocationNoCandidatesError::new(
                    "mock allocation produced no field schedules",
                )));
            }
            return Ok(mock);
        }

        let fields_file = write_temp_json(
            &json!({ "fields": fields }),
            "allocate_fields",
        )
        .map_err(|e| AllocationExecutionError::new(e.to_string()))?;
        let crops_file = write_temp_json(&json!({ "crops": crops }), "allocate_crops")
            .map_err(|e| AllocationExecutionError::new(e.to_string()))?;
        let weather_file = write_temp_json(weather_data, "allocate_weather")
            .map_err(|e| AllocationExecutionError::new(e.to_string()))?;

        let mut args = vec![
            "optimize".into(),
            "allocate".into(),
            "--fields-file".into(),
            path_string(&fields_file),
            "--crops-file".into(),
            path_string(&crops_file),
            "--planning-start".into(),
            planning_start.to_string(),
            "--planning-end".into(),
            planning_end.to_string(),
            "--weather-file".into(),
            path_string(&weather_file),
            "--objective".into(),
            objective.into(),
            "--format".into(),
            "json".into(),
        ];

        if let Some(rules) = interaction_rules {
            let rules_file = write_temp_json(rules, "allocate_rules")
                .map_err(|e| AllocationExecutionError::new(e.to_string()))?;
            args.push("--interaction-rules-file".into());
            args.push(path_string(&rules_file));
        }
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
        parse_allocate_result(&value).map_err(|e| Box::new(e) as Box<dyn std::error::Error + Send + Sync>)
    }
}

fn mock_id_string(value: &Value) -> Option<String> {
    value
        .as_str()
        .map(str::to_string)
        .or_else(|| value.as_i64().map(|id| id.to_string()))
}

fn mock_allocate_result(
    fields: &[Value],
    crops: &[Value],
    planning_start: Date,
    planning_end: Date,
) -> Value {
    let field_id = fields
        .first()
        .and_then(|f| f.get("field_id").or_else(|| f.get("id")))
        .and_then(mock_id_string)
        .unwrap_or_else(|| "1".into());
    let crop_id = crops
        .first()
        .and_then(|c| {
            c.pointer("/crop/crop_id")
                .or_else(|| c.get("crop_id"))
                .or_else(|| c.get("id"))
        })
        .and_then(mock_id_string)
        .unwrap_or_else(|| "1".into());
    let field_id_i64 = field_id.parse().unwrap_or(1);
    json!({
        "field_schedules": [{
            "field_id": field_id_i64,
            "allocations": [{
                "crop_id": crop_id,
                "start_date": planning_start.to_string(),
                "completion_date": planning_end.to_string(),
                "area_used": 1.0
            }]
        }],
        "summary": "mock-allocation"
    })
}

fn parse_allocate_result(raw: &Value) -> Result<Value, AllocationNoCandidatesError> {
    if let Some(schedules) = raw.get("field_schedules").and_then(|v| v.as_array()) {
        if schedules.is_empty() {
            return Err(AllocationNoCandidatesError::new(
                "allocation returned empty field_schedules",
            ));
        }
        return Ok(raw.clone());
    }
    if let Some(optimization) = raw.get("optimization_result") {
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
        return Ok(serde_json::json!({
            "field_schedules": field_schedules,
            "optimization_result": optimization,
            "summary": raw.get("summary"),
        }));
    }
    if raw.is_object() {
        return Err(AllocationNoCandidatesError::new(
            "allocation result has no field_schedules",
        ));
    }
    Err(AllocationNoCandidatesError::new(
        "allocation result empty",
    ))
}

fn map_daemon_error(err: AgrrDaemonError) -> AllocationExecutionError {
    AllocationExecutionError::new(err.to_string())
}
