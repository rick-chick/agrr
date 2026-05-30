//! agrr daemon: progress + predict for field cultivation climate.


use agrr_domain::field_cultivation::gateways::{
    FieldCultivationClimateProgressGateway, FieldCultivationPredictionGateway,
};
use serde_json::Value;
use tempfile::NamedTempFile;
use time::Date;

use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};

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

    fn empty_progress() -> Value {
        serde_json::json!({ "daily_progress": [] })
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
            return Self::empty_progress();
        }
        let Some(crop_file) = Self::write_temp_json(crop_requirement, "progress_crop") else {
            return Self::empty_progress();
        };
        let Some(weather_file) = Self::write_temp_json(weather_payload, "progress_weather") else {
            return Self::empty_progress();
        };
        let args = vec![
            "dummy_path".into(),
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
            Ok(v) => v,
            Err(AgrrDaemonError::NotRunning(_)) => Self::empty_progress(),
            Err(_) => Self::empty_progress(),
        }
    }
}

impl FieldCultivationPredictionGateway for FieldCultivationClimateAgrrGateway {
    fn predict(&self, historical_data: &Value, days: i64, model: &str) -> Option<Value> {
        if !self.client.daemon_running() {
            return None;
        }
        let hist_file = Self::write_temp_json(historical_data, "predict_hist")?;
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
            hist_file.path().to_string_lossy().into_owned(),
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
        if response.get("data").is_some() {
            return Some(response);
        }
        std::fs::read_to_string(&out_path)
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok())
    }
}
