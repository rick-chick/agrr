//! Ruby: `Adapters::Agrr::Gateways::WeatherDaemonGateway` + `DaemonClient#weather` (`--output` file).

use agrr_domain::weather_data::gateways::AgrrWeatherGateway;
use serde_json::Value;
use time::Date;

use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_response::parse_daemon_json_payload;
use crate::daemon_temp_file::read_json_file;

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

        let effective_source = effective_data_source(latitude, longitude, data_source);
        let out_file = tempfile::Builder::new()
            .prefix("weather_output_")
            .suffix(".json")
            .tempfile()?;
        let (_persisted, out_path) = out_file
            .keep()
            .map_err(|e| format!("weather output temp: {e}"))?;

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
            "--output".into(),
            out_path.to_string_lossy().into_owned(),
            "--json".into(),
        ];

        let wrapper = self.client.execute_daemon_args(&args)?;
        if let Ok(payload) = parse_daemon_json_payload(&wrapper) {
            if payload.get("data").is_some() {
                let _ = std::fs::remove_file(&out_path);
                return Ok(Some(payload));
            }
        }

        let raw = read_json_file(&out_path).map_err(|e| {
            AgrrDaemonError::CommandFailed(format!(
                "weather command did not produce JSON at {}: {e}",
                out_path.display()
            ))
        })?;
        let _ = std::fs::remove_file(&out_path);

        if raw.get("data").is_some() {
            return Ok(Some(raw));
        }
        Ok(None)
    }
}

fn effective_data_source(latitude: f64, longitude: f64, data_source: &str) -> String {
    let base = std::env::var("WEATHER_DATA_SOURCE").unwrap_or_else(|_| data_source.into());
    if base != "noaa" {
        return base;
    }
    if location_in_japan(latitude, longitude) {
        return "jma".into();
    }
    base
}

/// Ruby `DaemonClient#location_in_japan?`
fn location_in_japan(latitude: f64, longitude: f64) -> bool {
    if latitude == 0.0 && longitude == 0.0 {
        return false;
    }
    (20.0..=46.0).contains(&latitude) && (122.0..=154.0).contains(&longitude)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn japan_location_switches_noaa_to_jma() {
        assert_eq!(
            effective_data_source(35.0, 139.0, "noaa"),
            "jma"
        );
        assert_eq!(
            effective_data_source(40.0, -74.0, "noaa"),
            "noaa"
        );
    }

    #[test]
    fn weather_data_source_env_overrides() {
        let prev = std::env::var("WEATHER_DATA_SOURCE").ok();
        std::env::set_var("WEATHER_DATA_SOURCE", "openmeteo");
        assert_eq!(effective_data_source(35.0, 139.0, "noaa"), "openmeteo");
        match prev {
            Some(v) => std::env::set_var("WEATHER_DATA_SOURCE", v),
            None => std::env::remove_var("WEATHER_DATA_SOURCE"),
        }
    }
}
