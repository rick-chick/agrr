//! Parse agrr daemon wrapper responses (`stdout` / `stderr` / `exit_code`).

use std::path::Path;

use serde_json::Value;

use crate::AgrrDaemonError;

/// Extract JSON payload from daemon wrapper or raw JSON value.
pub fn parse_daemon_json_payload(wrapper: &Value) -> Result<Value, AgrrDaemonError> {
    if wrapper.get("stdout").is_none() && wrapper.get("exit_code").is_none() {
        return Ok(wrapper.clone());
    }

    let exit_code = wrapper.get("exit_code").and_then(|v| v.as_i64()).unwrap_or(-1);
    let stdout = wrapper
        .get("stdout")
        .and_then(|v| v.as_str())
        .unwrap_or("")
        .trim();
    let stderr = wrapper
        .get("stderr")
        .and_then(|v| v.as_str())
        .unwrap_or("");

    if exit_code != 0 {
        let message = if stderr.is_empty() {
            format!("agrr daemon exit_code={exit_code}")
        } else {
            format!("agrr daemon exit_code={exit_code}: {stderr}")
        };
        return Err(AgrrDaemonError::CommandFailed(message));
    }

    if stdout.is_empty() {
        if stderr.contains("Traceback (most recent call last)")
            || stderr.to_lowercase().contains("error")
        {
            return Err(AgrrDaemonError::CommandFailed(stderr.to_string()));
        }
        return Err(AgrrDaemonError::CommandFailed(
            "agrr daemon returned empty stdout".into(),
        ));
    }

    extract_json_value(stdout).map_err(AgrrDaemonError::CommandFailed)
}

/// `predict --output <file>` writes JSON to the file; stdout may contain LightGBM training logs.
pub fn ensure_daemon_command_success(wrapper: &Value) -> Result<(), AgrrDaemonError> {
    if wrapper.get("stdout").is_none() && wrapper.get("exit_code").is_none() {
        return Ok(());
    }

    let exit_code = wrapper.get("exit_code").and_then(|v| v.as_i64()).unwrap_or(-1);
    if exit_code == 0 {
        return Ok(());
    }
    let stderr = wrapper
        .get("stderr")
        .and_then(|v| v.as_str())
        .unwrap_or("");
    let message = if stderr.is_empty() {
        format!("agrr daemon exit_code={exit_code}")
    } else {
        format!("agrr daemon exit_code={exit_code}: {stderr}")
    };
    Err(AgrrDaemonError::CommandFailed(message))
}

pub fn read_daemon_output_json_file(path: &Path) -> Result<Value, AgrrDaemonError> {
    let content = std::fs::read_to_string(path).map_err(|e| {
        AgrrDaemonError::CommandFailed(format!("read daemon output file {}: {e}", path.display()))
    })?;
    if content.trim().is_empty() {
        return Err(AgrrDaemonError::CommandFailed(
            "agrr daemon output file is empty".into(),
        ));
    }
    serde_json::from_str(&content).map_err(|e| {
        AgrrDaemonError::CommandFailed(format!(
            "parse daemon output file {}: {e}",
            path.display()
        ))
    })
}

fn extract_json_value(stdout: &str) -> Result<Value, String> {
    let trimmed = stdout.trim();
    if let Ok(value) = serde_json::from_str::<Value>(trimmed) {
        return Ok(value);
    }
    let last_brace = trimmed.rfind('}');
    let last_bracket = trimmed.rfind(']');
    let last_pos = match (last_brace, last_bracket) {
        (Some(a), Some(b)) => Some(a.max(b)),
        (Some(a), None) => Some(a),
        (None, Some(b)) => Some(b),
        (None, None) => None,
    };
    if let Some(pos) = last_pos {
        let slice = &trimmed[..=pos];
        if let Ok(value) = serde_json::from_str::<Value>(slice) {
            return Ok(value);
        }
    }
    Err(format!("failed to parse daemon stdout as JSON: {trimmed}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;
    use std::io::Write;

    #[test]
    fn ensure_daemon_command_success_accepts_exit_zero() {
        let wrapper = json!({ "exit_code": 0, "stdout": "Training until..." });
        assert!(ensure_daemon_command_success(&wrapper).is_ok());
    }

    #[test]
    fn ensure_daemon_command_success_rejects_nonzero_exit() {
        let wrapper = json!({ "exit_code": 1, "stderr": "boom" });
        assert!(ensure_daemon_command_success(&wrapper).is_err());
    }

    #[test]
    fn read_daemon_output_json_file_reads_predictions_from_path() {
        let mut file = tempfile::NamedTempFile::new().unwrap();
        write!(
            file,
            r#"{{"predictions":[{{"date":"2026-01-01","temperature_max":10,"temperature_min":0}}]}}"#
        )
        .unwrap();
        let value = read_daemon_output_json_file(file.path()).unwrap();
        assert!(value.get("predictions").is_some());
    }
}
