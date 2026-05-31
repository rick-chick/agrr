//! agrr `predict` CLI for `PredictionGateway` (Rails `PredictionDaemonGateway` parity).

use agrr_domain::weather_data::gateways::PredictionGateway;
use rand::Rng;
use serde_json::{json, Value};
use crate::agrr_daemon_debug_dump::{copy_temp_file_to_debug, write_json_value_to_debug};
use crate::daemon_client::{AgrrDaemonClient, AgrrDaemonError};
use crate::daemon_response::{ensure_daemon_command_success, read_daemon_output_json_file};
use std::path::Path;
use crate::daemon_temp_file::{path_string, write_temp_json};

pub struct PredictionDaemonGateway {
    client: AgrrDaemonClient,
}

impl PredictionDaemonGateway {
    pub fn from_env() -> Self {
        Self {
            client: AgrrDaemonClient::from_env(),
        }
    }

    fn effective_model(requested: &str) -> String {
        if let Ok(m) = std::env::var("AGRR_PREDICT_MODEL") {
            let m = m.trim().to_lowercase();
            if !m.is_empty() {
                return m;
            }
        }
        if std::env::var("AGRR_USE_MOCK").as_deref() == Ok("true") {
            return "mock".into();
        }
        requested.to_string()
    }
}

#[cfg(test)]
mod effective_model_tests {
    use super::PredictionDaemonGateway;

    fn restore_env(key: &str, prev: Option<String>) {
        match prev {
            Some(v) => std::env::set_var(key, v),
            None => std::env::remove_var(key),
        }
    }

    fn with_env_vars<F>(vars: &[(&str, Option<&str>)], f: F)
    where
        F: FnOnce(),
    {
        let prev: Vec<_> = vars
            .iter()
            .map(|(k, _)| (*k, std::env::var(k).ok()))
            .collect();
        for (key, value) in vars {
            match value {
                Some(v) => std::env::set_var(key, v),
                None => std::env::remove_var(key),
            }
        }
        f();
        for (key, old) in prev {
            restore_env(key, old);
        }
    }

    #[test]
    fn effective_model_respects_agrr_use_mock_opt_in() {
        with_env_vars(
            &[("AGRR_USE_MOCK", None), ("AGRR_PREDICT_MODEL", None)],
            || {
                assert_eq!(
                    PredictionDaemonGateway::effective_model("lightgbm"),
                    "lightgbm"
                );
            },
        );
        with_env_vars(
            &[("AGRR_USE_MOCK", Some("true")), ("AGRR_PREDICT_MODEL", None)],
            || {
                assert_eq!(
                    PredictionDaemonGateway::effective_model("lightgbm"),
                    "mock"
                );
            },
        );
    }
}

impl PredictionGateway for PredictionDaemonGateway {
    fn predict(
        &self,
        historical_data: &Value,
        days: i64,
        model: &str,
    ) -> Result<Value, Box<dyn std::error::Error + Send + Sync>> {
        let data_count = historical_data
            .get("data")
            .and_then(|v| v.as_array())
            .map(|a| a.len())
            .unwrap_or(0);
        if data_count == 0 {
            return Err("Input historical data is empty".into());
        }

        let effective = Self::effective_model(model);
        if effective == "mock" {
            return Ok(generate_mock_predictions(historical_data, days));
        }

        let hist_file = write_temp_json(historical_data, "predict_hist")?;
        copy_temp_file_to_debug(hist_file.path(), "prediction_input");
        let out_file = tempfile::Builder::new()
            .prefix("predict_out_")
            .suffix(".json")
            .tempfile()?;
        let (_persisted, out_path) = out_file
            .keep()
            .map_err(|e| format!("predict output temp: {e}"))?;

        let mut args = vec![
            "predict".into(),
            "--input".into(),
            path_string(&hist_file),
            "--output".into(),
            out_path.to_string_lossy().into_owned(),
            "--days".into(),
            days.to_string(),
            "--model".into(),
            effective.clone(),
        ];
        if effective == "lightgbm" {
            args.push("--metrics".into());
            args.push("temperature,temperature_max,temperature_min".into());
        }

        let _hist_guard = hist_file;

        let wrapper = self
            .client
            .execute_daemon_args(&args)
            .map_err(|e: AgrrDaemonError| e.to_string())?;

        ensure_daemon_command_success(&wrapper).map_err(|e: AgrrDaemonError| e.to_string())?;
        let payload = read_daemon_output_json_file(Path::new(&out_path))
            .map_err(|e: AgrrDaemonError| e.to_string())?;
        write_json_value_to_debug("prediction_output", &payload);
        if payload.get("data").is_some() {
            write_json_value_to_debug("prediction_transformed", &payload);
            return Ok(payload);
        }
        if payload.get("predictions").is_some() {
            let transformed = transform_predictions_to_weather_data(&payload, historical_data);
            write_json_value_to_debug("prediction_transformed", &transformed);
            return Ok(transformed);
        }
        Err("prediction output missing data and predictions".into())
    }
}

fn generate_mock_predictions(historical_data: &Value, days: i64) -> Value {
    let stats = calculate_historical_stats(historical_data.get("data").and_then(|v| v.as_array()));
    let start = time::OffsetDateTime::now_utc().date();
    let mut rng = rand::thread_rng();
    let mut data = Vec::new();
    for i in 0..days {
        let date = start + time::Duration::days(i);
        let day_of_year = date.ordinal() as f64;
        let seasonal_temp = 15.0 + 10.0 * (2.0 * std::f64::consts::PI * (day_of_year - 80.0) / 365.0).sin();
        let random_variation = (rng.gen::<f64>() - 0.5) * 5.0;
        let base_temp = seasonal_temp + random_variation;
        let temp_max = base_temp + 5.0 + rng.gen::<f64>() * 3.0;
        let temp_min = base_temp - 5.0 - rng.gen::<f64>() * 3.0;
        let temp_mean = (temp_max + temp_min) / 2.0;
        data.push(json!({
            "time": date.to_string(),
            "temperature_2m_max": (temp_max * 100.0).round() / 100.0,
            "temperature_2m_min": (temp_min * 100.0).round() / 100.0,
            "temperature_2m_mean": (temp_mean * 100.0).round() / 100.0,
            "precipitation_sum": if rng.gen::<f64>() < 0.3 { (rng.gen::<f64>() * 10.0 * 100.0).round() / 100.0 } else { 0.0 },
            "sunshine_duration": (6.0 + rng.gen::<f64>() * 4.0) * 3600.0,
            "wind_speed_10m_max": ((2.0 + rng.gen::<f64>() * 5.0) * 100.0).round() / 100.0,
            "weather_code": if rng.gen::<f64>() < 0.7 { 0 } else { 61 },
        }));
    }
    let _ = stats;
    json!({ "data": data })
}

struct HistoricalStats {
    temp_range_half: f64,
    avg_precipitation: f64,
    avg_sunshine: f64,
    avg_wind_speed: f64,
}

fn default_stats() -> HistoricalStats {
    HistoricalStats {
        temp_range_half: 5.0,
        avg_precipitation: 0.0,
        avg_sunshine: 6.0 * 3600.0,
        avg_wind_speed: 3.0,
    }
}

fn calculate_historical_stats(data: Option<&Vec<Value>>) -> HistoricalStats {
    let Some(rows) = data else {
        return default_stats();
    };
    if rows.is_empty() {
        return default_stats();
    }
    let mut temp_ranges = Vec::new();
    let mut precip = Vec::new();
    let mut sunshine = Vec::new();
    let mut wind = Vec::new();
    for row in rows {
        if let (Some(max), Some(min)) = (
            row.get("temperature_2m_max").and_then(|v| v.as_f64()),
            row.get("temperature_2m_min").and_then(|v| v.as_f64()),
        ) {
            temp_ranges.push((max - min) / 2.0);
        }
        if let Some(p) = row.get("precipitation_sum").and_then(|v| v.as_f64()) {
            precip.push(p);
        }
        if let Some(s) = row.get("sunshine_duration").and_then(|v| v.as_f64()) {
            sunshine.push(s);
        }
        if let Some(w) = row.get("wind_speed_10m_max").and_then(|v| v.as_f64()) {
            wind.push(w);
        }
    }
    let avg = |v: &[f64], fallback: f64| {
        if v.is_empty() {
            fallback
        } else {
            v.iter().sum::<f64>() / v.len() as f64
        }
    };
    HistoricalStats {
        temp_range_half: avg(&temp_ranges, 5.0),
        avg_precipitation: avg(&precip, 0.0),
        avg_sunshine: avg(&sunshine, 6.0 * 3600.0),
        avg_wind_speed: avg(&wind, 3.0),
    }
}

fn transform_predictions_to_weather_data(
    prediction_result: &Value,
    historical_data: &Value,
) -> Value {
    let stats = calculate_historical_stats(
        historical_data.get("data").and_then(|v| v.as_array()),
    );
    let predictions = prediction_result
        .get("predictions")
        .and_then(|v| v.as_array())
        .cloned()
        .unwrap_or_default();
    let data: Vec<Value> = predictions
        .into_iter()
        .filter_map(|prediction| {
            let (temp_max, temp_min, temp_mean) =
                if let (Some(max), Some(min)) = (
                    prediction.get("temperature_max").and_then(|v| v.as_f64()),
                    prediction.get("temperature_min").and_then(|v| v.as_f64()),
                ) {
                    let mean = prediction
                        .get("temperature")
                        .or_else(|| prediction.get("predicted_value"))
                        .and_then(|v| v.as_f64())
                        .unwrap_or((max + min) / 2.0);
                    (max, min, mean)
                } else {
                    let mean = prediction
                        .get("predicted_value")
                        .and_then(|v| v.as_f64())?;
                    (
                        mean + stats.temp_range_half,
                        mean - stats.temp_range_half,
                        mean,
                    )
                };
            let time_str = prediction
                .get("date")
                .and_then(|v| v.as_str())
                .map(|d| d.split('T').next().unwrap_or(d).to_string())
                .or_else(|| {
                    prediction
                        .get("time")
                        .and_then(|v| v.as_str())
                        .map(str::to_string)
                })?;
            Some(json!({
                "time": time_str,
                "temperature_2m_max": (temp_max * 100.0).round() / 100.0,
                "temperature_2m_min": (temp_min * 100.0).round() / 100.0,
                "temperature_2m_mean": (temp_mean * 100.0).round() / 100.0,
                "precipitation_sum": (stats.avg_precipitation * 100.0).round() / 100.0,
                "sunshine_duration": (stats.avg_sunshine * 100.0).round() / 100.0,
                "wind_speed_10m_max": (stats.avg_wind_speed * 100.0).round() / 100.0,
                "weather_code": 0,
            }))
        })
        .collect();
    json!({ "data": data })
}
