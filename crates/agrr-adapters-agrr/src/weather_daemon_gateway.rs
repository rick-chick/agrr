//! Ruby: `Adapters::Agrr::Gateways::WeatherDaemonGateway`

use agrr_domain::weather_data::gateways::AgrrWeatherGateway;
use serde_json::Value;
use time::Date;

use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};

pub struct WeatherDaemonGateway {
    client: AgrrDaemonClient,
}

impl WeatherDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }
}

impl AgrrWeatherGateway for WeatherDaemonGateway {
    fn fetch_by_date_range(
        &self,
        latitude: f64,
        longitude: f64,
        start_date: Date,
        end_date: Date,
        data_source: &str,
    ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>> {
        if !self.client.daemon_running() {
            return Err(Box::new(AgrrDaemonError::NotRunning(
                "agrr daemon not running".into(),
            )));
        }
        let effective_source = std::env::var("WEATHER_DATA_SOURCE").unwrap_or_else(|_| data_source.into());
        let args = vec![
            "weather".into(),
            "--location".into(),
            format!("{latitude},{longitude}"),
            "--start-date".into(),
            start_date.to_string(),
            "--end-date".into(),
            end_date.to_string(),
            "--data-source".into(),
            effective_source,
            "--json".into(),
        ];
        let response = self.client.execute_daemon_args(&args)?;
        if response.get("data").is_some() {
            return Ok(Some(response));
        }
        Ok(None)
    }
}
