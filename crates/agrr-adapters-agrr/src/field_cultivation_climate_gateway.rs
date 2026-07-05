//! agrr daemon: progress + predict for field cultivation climate.


use agrr_domain::field_cultivation::gateways::{
    FieldCultivationClimateProgressGateway, FieldCultivationPredictionGateway,
};
use serde_json::Value;
use time::Date;

use crate::agrr_daemon_debug_dump::{copy_temp_file_to_debug, write_json_value_to_debug};
use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_response::{
    ensure_daemon_command_success, parse_daemon_json_payload, read_daemon_output_json_file,
};
use crate::daemon_temp_file::write_temp_json_path;
use crate::progress_daemon_normalize::normalize_progress_result;

pub struct FieldCultivationClimateAgrrGateway {
    client: AgrrDaemonClient,
}

impl FieldCultivationClimateAgrrGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }

    pub fn daemon_running(&self) -> bool {
        self.client.daemon_running()
    }

    /// Task schedule generation uses this to distinguish daemon failures from legitimately empty progress.
    pub fn calculate_progress_result(
        &self,
        crop_requirement: &Value,
        start_date: Date,
        weather_payload: &Value,
    ) -> Result<Value, AgrrDaemonError> {
        let crop_path = write_temp_json_path(crop_requirement, "progress_crop")
            .map_err(AgrrDaemonError::Io)?;
        let weather_path = write_temp_json_path(weather_payload, "progress_weather")
            .map_err(AgrrDaemonError::Io)?;
        copy_temp_file_to_debug(&crop_path, "progress_crop");
        copy_temp_file_to_debug(&weather_path, "progress_weather");
        let args = vec![
            "progress".into(),
            "--crop-file".into(),
            crop_path.to_string_lossy().into_owned(),
            "--start-date".into(),
            start_date.to_string(),
            "--weather-file".into(),
            weather_path.to_string_lossy().into_owned(),
            "--format".into(),
            "json".into(),
        ];
        let wrapper = self.client.execute_daemon_args(&args)?;
        let payload = parse_daemon_json_payload(&wrapper)?;
        Ok(normalize_progress_result(&payload))
    }
}

impl FieldCultivationClimateProgressGateway for FieldCultivationClimateAgrrGateway {
    fn calculate_progress(
        &self,
        crop_requirement: &Value,
        start_date: Date,
        weather_payload: &Value,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        self.calculate_progress_result(crop_requirement, start_date, weather_payload)
            .map_err(|err| Box::new(err) as Box<dyn std::error::Error + Send + Sync>)
    }
}

impl FieldCultivationPredictionGateway for FieldCultivationClimateAgrrGateway {
    fn predict(&self, historical_data: &Value, days: i64, model: &str) -> Option<Value> {
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
