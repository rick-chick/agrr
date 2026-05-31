//! agrr daemon: progress + predict for field cultivation climate.


use agrr_domain::field_cultivation::gateways::{
    FieldCultivationClimateProgressGateway, FieldCultivationPredictionGateway,
};
use serde_json::Value;
use tempfile::NamedTempFile;
use time::Date;

use crate::agrr_daemon_debug_dump::{copy_temp_file_to_debug, write_json_value_to_debug};
use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_response::{
    ensure_daemon_command_success, parse_daemon_json_payload, read_daemon_output_json_file,
};
use crate::daemon_temp_file::write_temp_json_path;
use crate::progress_daemon_normalize::{empty_progress_result, normalize_progress_result};

pub struct FieldCultivationClimateAgrrGateway {
    client: AgrrDaemonClient,
}

impl FieldCultivationClimateAgrrGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }

    fn write_temp_json(data: &Value, prefix: &str) -> Option<NamedTempFile> {
        let file = NamedTempFile::with_prefix(prefix).ok()?;
        std::io::Write::write_all(
            &mut file.as_file(),
            serde_json::to_string(data).ok()?.as_bytes(),
        )
        .ok()?;
        file.as_file().sync_all().ok()?;
        Some(file)
    }
}

impl FieldCultivationClimateProgressGateway for FieldCultivationClimateAgrrGateway {
    fn calculate_progress(
        &self,
        crop_requirement: &Value,
        start_date: Date,
        weather_payload: &Value,
    ) -> Value {
        if !self.client.daemon_running() {
            return empty_progress_result();
        }
        let Some(crop_file) = Self::write_temp_json(crop_requirement, "progress_crop") else {
            return empty_progress_result();
        };
        let Some(weather_file) = Self::write_temp_json(weather_payload, "progress_weather") else {
            return empty_progress_result();
        };
        copy_temp_file_to_debug(crop_file.path(), "progress_crop");
        copy_temp_file_to_debug(weather_file.path(), "progress_weather");
        // Rails `DaemonClient#progress`: no leading dummy_path (BaseGatewayV2 strips it).
        let args = vec![
            "progress".into(),
            "--crop-file".into(),
            crop_file.path().to_string_lossy().into_owned(),
            "--start-date".into(),
            start_date.to_string(),
            "--weather-file".into(),
            weather_file.path().to_string_lossy().into_owned(),
            "--format".into(),
            "json".into(),
        ];
        match self.client.execute_daemon_args(&args) {
            Ok(wrapper) => match parse_daemon_json_payload(&wrapper) {
                Ok(payload) => normalize_progress_result(&payload),
                Err(_) => empty_progress_result(),
            },
            Err(AgrrDaemonError::NotRunning(_)) => empty_progress_result(),
            Err(_) => empty_progress_result(),
        }
    }
}

impl FieldCultivationPredictionGateway for FieldCultivationClimateAgrrGateway {
    fn predict(&self, historical_data: &Value, days: i64, model: &str) -> Option<Value> {
        if !self.client.daemon_running() {
            return None;
        }
        let hist_file = write_temp_json_path(historical_data, "predict_hist").ok()?;
        copy_temp_file_to_debug(&hist_file, "prediction_input");
        let out_path = std::env::temp_dir().join(format!(
            "agrr_predict_{}",
            std::time::SystemTime::now()
                .duration_since(std::time::UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));
        let args = vec![
            "predict".into(),
            "--input".into(),
            hist_file.to_string_lossy().into_owned(),
            "--output".into(),
            out_path.to_string_lossy().into_owned(),
            "--days".into(),
            days.to_string(),
            "--model".into(),
            model.into(),
            "--format".into(),
            "json".into(),
        ];
        let response = self.client.execute_daemon_args(&args).ok()?;
        ensure_daemon_command_success(&response).ok()?;
        let payload = read_daemon_output_json_file(&out_path).ok()?;
        write_json_value_to_debug("prediction_output", &payload);
        if payload.get("data").is_some() {
            write_json_value_to_debug("prediction_transformed", &payload);
            return Some(payload);
        }
        if payload.get("predictions").is_some() {
            return Some(payload);
        }
        None
    }
}
