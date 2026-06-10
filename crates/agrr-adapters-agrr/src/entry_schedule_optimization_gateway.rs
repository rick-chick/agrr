//! Entry schedule `optimize period` via agrr daemon.

use agrr_domain::cultivation_plan::errors::EntryScheduleOptimizationError;
use agrr_domain::cultivation_plan::gateways::EntryScheduleOptimizationGateway;
use serde_json::Value;
use tempfile::NamedTempFile;
use time::Date;

use crate::agrr_daemon_debug_dump::copy_temp_file_to_debug;
use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};

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
            "name": "entry_field",
            "area": 1.0,
            "daily_fixed_cost": 0.01
        });
        let field_file = Self::write_temp_json(&field, "entry_field")?;
        copy_temp_file_to_debug(weather_file.path(), "optimization_weather");
        copy_temp_file_to_debug(field_file.path(), "optimization_field");
        copy_temp_file_to_debug(crop_file.path(), "optimization_crop");
        let mut args = vec![
            "optimize".into(),
            "period".into(),
            "--crop-file".into(),
            crop_file.path().to_string_lossy().into_owned(),
            "--weather-file".into(),
            weather_file.path().to_string_lossy().into_owned(),
            "--field-file".into(),
            field_file.path().to_string_lossy().into_owned(),
            "--evaluation-start".into(),
            evaluation_start.to_string(),
            "--evaluation-end".into(),
            evaluation_end.to_string(),
            "--format".into(),
            "json".into(),
        ];
        if let Some(v) = crop_variety.filter(|s| !s.is_empty()) {
            args.push("--crop-name".into());
            args.push(crop_name.to_string());
            args.push("--crop-variety".into());
            args.push(v.to_string());
        } else {
            args.push("--crop-name".into());
            args.push(crop_name.to_string());
        }
        match self.client.execute_daemon_args(&args) {
            Ok(v) => Ok(v),
            Err(AgrrDaemonError::NotRunning(msg)) => Err(Box::new(
                EntryScheduleOptimizationError::new("daemon_unavailable", msg),
            )),
            Err(e) => Err(Box::new(EntryScheduleOptimizationError::new(
                "execution_failed",
                e.to_string(),
            ))),
        }
    }
}
