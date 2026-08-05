//! Structured security audit events for Cloud Logging (`textPayload` / JSON grep).

use serde_json::{json, Value};
use time::format_description::well_known::Iso8601;
use time::OffsetDateTime;

pub const EVENT_LOGIN_SUCCESS: &str = "login_success";
pub const EVENT_LOGOUT: &str = "logout";
pub const EVENT_API_KEY_GENERATE: &str = "api_key_generate";
pub const EVENT_API_KEY_REGENERATE: &str = "api_key_regenerate";
pub const EVENT_REFERENCE_MASTER_CHANGE: &str = "reference_master_change";

const FORBIDDEN_FIELD_FRAGMENTS: [&str; 6] = [
    "session_id",
    "api_key",
    "access_token",
    "oauth_token",
    "backdoor_token",
    "confirmation_token",
];

/// Build a JSON audit line without emitting (unit tests).
pub fn format_event(
    event_type: &str,
    user_id: Option<i64>,
    extra: &Value,
) -> Result<String, String> {
    let timestamp = OffsetDateTime::now_utc()
        .format(&Iso8601::DEFAULT)
        .map_err(|e| e.to_string())?;
    let mut payload = json!({
        "event_type": event_type,
        "timestamp": timestamp,
    });
    if let Some(id) = user_id {
        payload["user_id"] = json!(id);
    }
    if let Some(obj) = extra.as_object() {
        for (key, value) in obj {
            if is_forbidden_field(key) {
                return Err(format!("forbidden audit field: {key}"));
            }
            payload[key] = value.clone();
        }
    }
    let line = serde_json::to_string(&payload).map_err(|e| e.to_string())?;
    if line.contains("session_id=") {
        return Err("forbidden session_id fragment in audit line".into());
    }
    Ok(line)
}

fn is_forbidden_field(key: &str) -> bool {
    let lower = key.to_ascii_lowercase();
    FORBIDDEN_FIELD_FRAGMENTS
        .iter()
        .any(|frag| lower.contains(frag))
}

/// Emit one structured audit event to stderr (Cloud Run `textPayload`).
pub fn emit(event_type: &str, user_id: Option<i64>, extra: &Value) {
    match format_event(event_type, user_id, extra) {
        Ok(line) => eprintln!("{line}"),
        Err(err) => tracing::error!("security audit log skipped: {err}"),
    }
}

pub fn log_login_success(user_id: i64) {
    emit(EVENT_LOGIN_SUCCESS, Some(user_id), &json!({}));
}

pub fn log_logout(user_id: i64) {
    emit(EVENT_LOGOUT, Some(user_id), &json!({}));
}

pub fn log_api_key_event(user_id: i64, regenerate: bool) {
    let event_type = if regenerate {
        EVENT_API_KEY_REGENERATE
    } else {
        EVENT_API_KEY_GENERATE
    };
    emit(event_type, Some(user_id), &json!({}));
}

pub fn log_reference_master_change(
    user_id: i64,
    resource_type: &str,
    resource_id: i64,
    action: &str,
) {
    emit(
        EVENT_REFERENCE_MASTER_CHANGE,
        Some(user_id),
        &json!({
            "resource_type": resource_type,
            "resource_id": resource_id,
            "action": action,
        }),
    );
}

pub fn log_if_reference_master(
    user_id: i64,
    resource_type: &str,
    action: &str,
    is_reference: bool,
    resource_id: Option<i64>,
) {
    if is_reference {
        if let Some(resource_id) = resource_id {
            log_reference_master_change(user_id, resource_type, resource_id, action);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn format_event_includes_required_fields() {
        let line = format_event(EVENT_LOGIN_SUCCESS, Some(42), &json!({}))
            .expect("format audit event");
        let parsed: Value = serde_json::from_str(&line).expect("valid JSON");
        assert_eq!(parsed["event_type"], EVENT_LOGIN_SUCCESS);
        assert_eq!(parsed["user_id"], 42);
        assert!(parsed["timestamp"].is_string());
        assert!(
            parsed["timestamp"]
                .as_str()
                .unwrap()
                .contains('T'),
            "timestamp should be RFC3339-like"
        );
    }

    #[test]
    fn format_event_rejects_sensitive_fields() {
        let err = format_event(
            EVENT_API_KEY_GENERATE,
            Some(1),
            &json!({ "api_key": "secret" }),
        )
        .unwrap_err();
        assert!(err.contains("forbidden"));
    }

    #[test]
    fn format_event_allows_reference_master_metadata() {
        let line = format_event(
            EVENT_REFERENCE_MASTER_CHANGE,
            Some(7),
            &json!({
                "resource_type": "pest",
                "resource_id": 99,
                "action": "update",
            }),
        )
        .expect("format reference master event");
        let parsed: Value = serde_json::from_str(&line).expect("valid JSON");
        assert_eq!(parsed["event_type"], EVENT_REFERENCE_MASTER_CHANGE);
        assert_eq!(parsed["resource_type"], "pest");
        assert_eq!(parsed["resource_id"], 99);
        assert_eq!(parsed["action"], "update");
        let serialized = line.to_ascii_lowercase();
        assert!(!serialized.contains("session_id"));
        assert!(!serialized.contains("api_key"));
    }
}
