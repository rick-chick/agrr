//! agrr `predict` CLI for `PredictionGateway`.

use agrr_domain::weather_data::gateways::PredictionGateway;
use serde_json::Value;
use tempfile::NamedTempFile;

use crate::daemon_client::AgrrDaemonClient;

pub struct PredictionDaemonGateway {
    client: AgrrDaemonClient,
}

impl PredictionDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }
}

impl PredictionGateway for PredictionDaemonGateway {
    fn predict(
        &self,
        historical_data: &Value,
        days: i64,
        model: &str,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        let hist_file = NamedTempFile::with_prefix("predict_hist")?;
        std::io::Write::write_all(
            &mut hist_file.as_file(),
            serde_json::to_string(historical_data)?.as_bytes(),
        )?;
        hist_file.as_file().sync_all()?;
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
        let response = self.client.execute_daemon_args(&args)?;
        if response.get("data").is_some() {
            return Ok(response);
        }
        let text = std::fs::read_to_string(&out_path)?;
        Ok(serde_json::from_str(&text)?)
    }
}
