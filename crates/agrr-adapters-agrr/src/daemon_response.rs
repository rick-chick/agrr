//! Parse agrr daemon wrapper responses (`stdout` / `stderr` / `exit_code`).

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

    extract_json_value(stdout).map_err(|e| AgrrDaemonError::CommandFailed(e))
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
