//! Ruby: `Adapters::Agrr::Gateways::WeatherDaemonGateway` + `DaemonClient#weather` (`--output` file).

use agrr_domain::weather_data::gateways::AgrrWeatherGateway;
use serde_json::Value;
use time::Date;

use std::path::Path;

use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_response::{ensure_daemon_command_success, parse_daemon_json_payload};

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
        ensure_daemon_command_success(&wrapper).map_err(map_daemon_err)?;
        resolve_weather_fetch_output(&wrapper, &out_path).map_err(map_daemon_err)
    }
}

/// agrr normal fetch: exit 0 with no `--output` file means nothing new to ingest (`None` skip).
fn resolve_weather_fetch_output(
    wrapper: &Value,
    out_path: &Path,
) -> Result<Option<Value>, AgrrDaemonError> {
    if let Ok(payload) = parse_daemon_json_payload(wrapper) {
        if weather_payload_has_rows(&payload) {
            let _ = std::fs::remove_file(out_path);
            return Ok(Some(payload));
        }
    }

    if out_path.exists() {
        let content = std::fs::read_to_string(out_path).map_err(|e| {
            AgrrDaemonError::CommandFailed(format!(
                "weather command did not produce JSON at {}: {e}",
                out_path.display()
            ))
        })?;
        let _ = std::fs::remove_file(out_path);
        if content.trim().is_empty() {
            return Ok(None);
        }
        let raw = serde_json::from_str(&content).map_err(|e| {
            AgrrDaemonError::CommandFailed(format!(
                "weather command did not produce JSON at {}: {e}",
                out_path.display()
            ))
        })?;
        if weather_payload_has_rows(&raw) {
            return Ok(Some(raw));
        }
    }

    Ok(None)
}

fn map_daemon_err(error: AgrrDaemonError) -> Box<dyn std::error::Error + Send + Sync> {
    Box::new(error)
}

fn weather_payload_has_rows(payload: &Value) -> bool {
    payload
        .get("data")
        .and_then(|data| data.as_array())
        .is_some_and(|rows| !rows.is_empty())
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
    use serde_json::json;
    use std::io::Write;

    #[test]
    fn resolve_weather_fetch_output_returns_none_when_exit_zero_and_no_output_file() {
        let dir = tempfile::tempdir().expect("tempdir");
        let missing = dir.path().join("weather_output_missing.json");
        let wrapper = json!({ "exit_code": 0, "stdout": "", "stderr": "" });

        let result = resolve_weather_fetch_output(&wrapper, &missing).expect("resolve");

        assert_eq!(result, None);
    }

    #[test]
    fn resolve_weather_fetch_output_returns_none_when_output_file_is_empty() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("weather_output_empty.json");
        std::fs::write(&path, "").expect("write empty");

        let wrapper = json!({ "exit_code": 0, "stdout": "", "stderr": "" });
        let result = resolve_weather_fetch_output(&wrapper, &path).expect("resolve");

        assert_eq!(result, None);
        assert!(!path.exists(), "empty output file should be removed");
    }

    #[test]
    fn resolve_weather_fetch_output_returns_some_when_output_file_has_rows() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("weather_output_rows.json");
        let payload = json!({
            "data": [{"time": "2026-06-10T00:00:00", "temperature_2m_max": 20.0}],
            "location": {"latitude": 34.7, "longitude": 136.5}
        });
        let mut file = std::fs::File::create(&path).expect("create");
        write!(file, "{}", serde_json::to_string(&payload).expect("json")).expect("write");

        let wrapper = json!({ "exit_code": 0, "stdout": "", "stderr": "" });
        let result = resolve_weather_fetch_output(&wrapper, &path).expect("resolve");

        assert!(result.is_some());
        assert_eq!(
            result
                .and_then(|v| v.get("data").and_then(|d| d.as_array()).map(|a| a.len()))
                .unwrap_or(0),
            1
        );
    }

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
