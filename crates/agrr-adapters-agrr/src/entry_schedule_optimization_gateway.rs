//! Entry schedule `optimize period` via agrr daemon.

use std::path::PathBuf;

use agrr_domain::cultivation_plan::errors::EntryScheduleOptimizationError;
use agrr_domain::cultivation_plan::gateways::EntryScheduleOptimizationGateway;
use serde_json::Value;
use time::Date;

use crate::agrr_daemon_debug_dump::copy_temp_file_to_debug;
use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_response::parse_daemon_json_payload;
use crate::daemon_temp_file::write_temp_json_path;
use crate::daemon_unavailable::DAEMON_UNAVAILABLE_MESSAGE;

pub struct EntryScheduleOptimizationAgrrDaemonGateway {
    client: AgrrDaemonClient,
}

impl EntryScheduleOptimizationAgrrDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }

    fn write_temp_json_path(
        data: &Value,
        prefix: &str,
    ) -> Result<PathBuf, EntryScheduleOptimizationError> {
        write_temp_json_path(data, prefix)
            .map_err(|e| EntryScheduleOptimizationError::new("execution_failed", e.to_string()))
    }

    fn remove_temp_path(path: &PathBuf) {
        let _ = std::fs::remove_file(path);
    }
}

impl EntryScheduleOptimizationGateway for EntryScheduleOptimizationAgrrDaemonGateway {
    fn optimize_period(
        &self,
        crop_name: &str,
        crop_variety: Option<&str>,
        weather_data: &Value,
        evaluation_start: Date,
        evaluation_end: Date,
        crop_requirement: &Value,
        _crop: &Value,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        let crop_path = Self::write_temp_json_path(crop_requirement, "entry_crop")?;
        let weather_path = Self::write_temp_json_path(weather_data, "entry_weather")?;
        let field = build_entry_field_payload();
        let field_path = Self::write_temp_json_path(&field, "entry_field")?;
        copy_temp_file_to_debug(&weather_path, "optimization_weather");
        copy_temp_file_to_debug(&field_path, "optimization_field");
        copy_temp_file_to_debug(&crop_path, "optimization_crop");
        let args = build_optimize_period_args(
            &crop_path,
            &weather_path,
            &field_path,
            evaluation_start,
            evaluation_end,
        );
        let _ = (crop_name, crop_variety);
        let result = match self.client.execute_daemon_args(&args) {
            Ok(wrapper) => parse_daemon_json_payload(&wrapper).map_err(|e| match e {
                AgrrDaemonError::NotRunning(_) => Box::new(EntryScheduleOptimizationError::new(
                    "daemon_unavailable",
                    DAEMON_UNAVAILABLE_MESSAGE,
                )) as Box<dyn std::error::Error + Send + Sync>,
                other => Box::new(EntryScheduleOptimizationError::new(
                    "execution_failed",
                    other.to_string(),
                )) as Box<dyn std::error::Error + Send + Sync>,
            }),
            Err(AgrrDaemonError::NotRunning(_)) => Err(Box::new(
                EntryScheduleOptimizationError::new(
                    "daemon_unavailable",
                    DAEMON_UNAVAILABLE_MESSAGE,
                ),
            ) as Box<dyn std::error::Error + Send + Sync>),
            Err(e) => Err(Box::new(EntryScheduleOptimizationError::new(
                "execution_failed",
                e.to_string(),
            )) as Box<dyn std::error::Error + Send + Sync>),
        };
        Self::remove_temp_path(&crop_path);
        Self::remove_temp_path(&weather_path);
        Self::remove_temp_path(&field_path);
        result
    }
}

fn build_entry_field_payload() -> Value {
    serde_json::json!({
        "field_id": "entry_field",
        "name": "entry_field",
        "area": 1.0,
        "daily_fixed_cost": 0.01
    })
}

fn build_optimize_period_args(
    crop_file: &std::path::Path,
    weather_file: &std::path::Path,
    field_file: &std::path::Path,
    evaluation_start: Date,
    evaluation_end: Date,
) -> Vec<String> {
    vec![
        "optimize".into(),
        "period".into(),
        "--crop-file".into(),
        crop_file.to_string_lossy().into_owned(),
        "--weather-file".into(),
        weather_file.to_string_lossy().into_owned(),
        "--field-file".into(),
        field_file.to_string_lossy().into_owned(),
        "--evaluation-start".into(),
        evaluation_start.to_string(),
        "--evaluation-end".into(),
        evaluation_end.to_string(),
        "--format".into(),
        "json".into(),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use time::macros::date;

    #[test]
    fn write_temp_json_path_persists_json_suffix_for_agrr_cli() {
        let path =
            EntryScheduleOptimizationAgrrDaemonGateway::write_temp_json_path(&json!({ "ok": true }), "entry_crop")
                .expect("temp json");
        assert!(
            path.to_string_lossy().ends_with(".json"),
            "agrr --*-file requires .json extension, got {}",
            path.display()
        );
        EntryScheduleOptimizationAgrrDaemonGateway::remove_temp_path(&path);
        assert!(!path.exists());
    }

    #[test]
    fn build_entry_field_payload_includes_field_id_required_by_agrr() {
        let field = build_entry_field_payload();
        assert_eq!(
            field.get("field_id").and_then(|v| v.as_str()),
            Some("entry_field")
        );
        assert!(field.get("name").is_some());
        assert!(field.get("area").is_some());
        assert!(field.get("daily_fixed_cost").is_some());
    }

    #[test]
    fn build_optimize_period_args_omits_crop_name_and_variety() {
        let args = build_optimize_period_args(
            std::path::Path::new("/tmp/crop.json"),
            std::path::Path::new("/tmp/weather.json"),
            std::path::Path::new("/tmp/field.json"),
            date!(2025-08-28),
            date!(2027-06-30),
        );
        assert!(!args.contains(&"--crop-name".to_string()));
        assert!(!args.contains(&"--crop-variety".to_string()));
        assert_eq!(
            args,
            vec![
                "optimize",
                "period",
                "--crop-file",
                "/tmp/crop.json",
                "--weather-file",
                "/tmp/weather.json",
                "--field-file",
                "/tmp/field.json",
                "--evaluation-start",
                "2025-08-28",
                "--evaluation-end",
                "2027-06-30",
                "--format",
                "json",
            ]
        );
    }
}
