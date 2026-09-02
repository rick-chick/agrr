//! Entry schedule `optimize period` via agrr daemon.

use agrr_domain::cultivation_plan::errors::EntryScheduleOptimizationError;
use agrr_domain::cultivation_plan::gateways::EntryScheduleOptimizationGateway;
use serde_json::Value;
use tempfile::NamedTempFile;
use time::Date;

use crate::agrr_daemon_debug_dump::copy_temp_file_to_debug;
use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_response::parse_daemon_json_payload;
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

    fn write_temp_json(data: &Value, prefix: &str) -> Result<NamedTempFile, EntryScheduleOptimizationError> {
        let file = NamedTempFile::with_prefix(prefix).map_err(|e| {
            EntryScheduleOptimizationError::new("execution_failed", e.to_string())
        })?;
        std::io::Write::write_all(
            &mut file.as_file(),
            serde_json::to_string(data).map_err(|e| {
                EntryScheduleOptimizationError::new("execution_failed", e.to_string())
            })?
            .as_bytes(),
        )
        .map_err(|e| EntryScheduleOptimizationError::new("execution_failed", e.to_string()))?;
        file.as_file()
            .sync_all()
            .map_err(|e| EntryScheduleOptimizationError::new("execution_failed", e.to_string()))?;
        Ok(file)
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
        let crop_file = Self::write_temp_json(crop_requirement, "entry_crop")?;
        let weather_file = Self::write_temp_json(weather_data, "entry_weather")?;
        let field = serde_json::json!({
            "field_id": "entry_field",
            "name": "entry_field",
            "area": 1.0,
            "daily_fixed_cost": 0.01
        });
        let field_file = Self::write_temp_json(&field, "entry_field")?;
        copy_temp_file_to_debug(weather_file.path(), "optimization_weather");
        copy_temp_file_to_debug(field_file.path(), "optimization_field");
        copy_temp_file_to_debug(crop_file.path(), "optimization_crop");
        let args = build_optimize_period_args(
            crop_file.path(),
            weather_file.path(),
            field_file.path(),
            evaluation_start,
            evaluation_end,
        );
        let _ = (crop_name, crop_variety);
        match self.client.execute_daemon_args(&args) {
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
            )),
            Err(e) => Err(Box::new(EntryScheduleOptimizationError::new(
                "execution_failed",
                e.to_string(),
            ))),
        }
    }
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
    use time::macros::date;

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
