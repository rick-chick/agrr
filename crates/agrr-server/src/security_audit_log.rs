//! Structured security audit events for Cloud Logging (`textPayload` JSON grep).
//!
//! Edge-only: no domain business rules. Emits one JSON object per line to stderr.

use serde::Serialize;
use time::format_description::well_known::Rfc3339;
use time::OffsetDateTime;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum SecurityAuditEventType {
    LoginSuccess,
    Logout,
    ApiKeyGenerate,
    ApiKeyRegenerate,
    ReferenceMasterAdminChange,
    BackdoorOperation,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct SecurityAuditRecord {
    pub event_type: SecurityAuditEventType,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub user_id: Option<i64>,
    pub timestamp: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub resource_type: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub resource_id: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub action: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub outcome: Option<String>,
}

impl SecurityAuditRecord {
    pub fn new(event_type: SecurityAuditEventType, user_id: Option<i64>) -> Self {
        Self {
            event_type,
            user_id,
            timestamp: current_timestamp_rfc3339(),
            resource_type: None,
            resource_id: None,
            action: None,
            outcome: None,
        }
    }

    pub fn with_resource(
        mut self,
        resource_type: impl Into<String>,
        resource_id: i64,
        action: impl Into<String>,
    ) -> Self {
        self.resource_type = Some(resource_type.into());
        self.resource_id = Some(resource_id);
        self.action = Some(action.into());
        self
    }

    pub fn with_outcome(mut self, outcome: impl Into<String>) -> Self {
        self.outcome = Some(outcome.into());
        self
    }
}

fn current_timestamp_rfc3339() -> String {
    OffsetDateTime::now_utc()
        .format(&Rfc3339)
        .unwrap_or_else(|_| OffsetDateTime::now_utc().to_string())
}

pub fn format_security_audit_log(record: &SecurityAuditRecord) -> String {
    serde_json::to_string(record).unwrap_or_else(|_| {
        format!(
            "{{\"event_type\":\"serialization_error\",\"timestamp\":\"{}\"}}",
            current_timestamp_rfc3339()
        )
    })
}

pub fn emit_security_audit_log(record: SecurityAuditRecord) {
    let line = format_security_audit_log(&record);
    #[cfg(test)]
    if let Ok(guard) = TEST_AUDIT_SINK.lock() {
        if let Some(sink) = guard.as_ref() {
            sink(line);
            return;
        }
    }
    // Cloud Run surfaces stderr as textPayload; JSON per line is grep-friendly.
    eprintln!("{line}");
}

#[cfg(test)]
static TEST_AUDIT_SINK: std::sync::Mutex<Option<Box<dyn Fn(String) + Send + Sync>>> =
    std::sync::Mutex::new(None);

#[cfg(test)]
pub fn set_test_audit_sink(
    sink: Option<Box<dyn Fn(String) + Send + Sync>>,
) -> TestAuditSinkGuard {
    let mut guard = TEST_AUDIT_SINK.lock().expect("test audit sink lock");
    *guard = sink;
    TestAuditSinkGuard
}

#[cfg(test)]
pub struct TestAuditSinkGuard;

#[cfg(test)]
impl Drop for TestAuditSinkGuard {
    fn drop(&mut self) {
        let mut guard = TEST_AUDIT_SINK.lock().expect("test audit sink lock");
        *guard = None;
    }
}

pub fn log_login_success(user_id: i64) {
    emit_security_audit_log(SecurityAuditRecord::new(
        SecurityAuditEventType::LoginSuccess,
        Some(user_id),
    ));
}

pub fn log_logout(user_id: i64) {
    emit_security_audit_log(SecurityAuditRecord::new(
        SecurityAuditEventType::Logout,
        Some(user_id),
    ));
}

pub fn log_api_key_generate(user_id: i64) {
    emit_security_audit_log(SecurityAuditRecord::new(
        SecurityAuditEventType::ApiKeyGenerate,
        Some(user_id),
    ));
}

pub fn log_api_key_regenerate(user_id: i64) {
    emit_security_audit_log(SecurityAuditRecord::new(
        SecurityAuditEventType::ApiKeyRegenerate,
        Some(user_id),
    ));
}

pub fn log_reference_master_admin_change(
    user_id: i64,
    resource_type: &str,
    resource_id: i64,
    action: &str,
) {
    emit_security_audit_log(
        SecurityAuditRecord::new(
            SecurityAuditEventType::ReferenceMasterAdminChange,
            Some(user_id),
        )
        .with_resource(resource_type, resource_id, action),
    );
}

/// Records a backdoor API operation without logging token material.
pub fn log_backdoor_operation(action: &str, resource_id: Option<i64>, outcome: &str) {
    let mut record = SecurityAuditRecord::new(SecurityAuditEventType::BackdoorOperation, None)
        .with_outcome(outcome);
    record.action = Some(action.into());
    record.resource_type = Some("backdoor".into());
    if let Some(id) = resource_id {
        record.resource_id = Some(id);
    }
    emit_security_audit_log(record);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn format_includes_required_fields_as_json() {
        let line = format_security_audit_log(&SecurityAuditRecord {
            event_type: SecurityAuditEventType::LoginSuccess,
            user_id: Some(42),
            timestamp: "2026-08-05T12:00:00Z".into(),
            resource_type: None,
            resource_id: None,
            action: None,
            outcome: None,
        });
        let json: serde_json::Value = serde_json::from_str(&line).expect("valid JSON");
        assert_eq!("login_success", json["event_type"].as_str().unwrap());
        assert_eq!(42, json["user_id"].as_i64().unwrap());
        assert_eq!("2026-08-05T12:00:00Z", json["timestamp"].as_str().unwrap());
    }

    #[test]
    fn format_reference_master_change_includes_resource_metadata() {
        let line = format_security_audit_log(
            &SecurityAuditRecord::new(
                SecurityAuditEventType::ReferenceMasterAdminChange,
                Some(1),
            )
            .with_resource("pest", 99, "update"),
        );
        let json: serde_json::Value = serde_json::from_str(&line).expect("valid JSON");
        assert_eq!(
            "reference_master_admin_change",
            json["event_type"].as_str().unwrap()
        );
        assert_eq!("pest", json["resource_type"].as_str().unwrap());
        assert_eq!(99, json["resource_id"].as_i64().unwrap());
        assert_eq!("update", json["action"].as_str().unwrap());
    }

    #[test]
    fn format_backdoor_operation_includes_action_and_outcome() {
        let mut record = SecurityAuditRecord::new(SecurityAuditEventType::BackdoorOperation, None)
            .with_outcome("success");
        record.action = Some("users_list".into());
        record.resource_type = Some("backdoor".into());
        let line = format_security_audit_log(&record);
        let json: serde_json::Value = serde_json::from_str(&line).expect("valid JSON");
        assert_eq!(
            "backdoor_operation",
            json["event_type"].as_str().unwrap()
        );
        assert_eq!("users_list", json["action"].as_str().unwrap());
        assert_eq!("success", json["outcome"].as_str().unwrap());
        assert_eq!("backdoor", json["resource_type"].as_str().unwrap());
    }

    #[test]
    fn log_backdoor_operation_emits_structured_json_without_token() {
        let captured = std::sync::Arc::new(std::sync::Mutex::new(Vec::<String>::new()));
        let captured_clone = captured.clone();
        let _guard = set_test_audit_sink(Some(Box::new(move |line| {
            captured_clone.lock().expect("lock").push(line);
        })));

        log_backdoor_operation("users_list", None, "success");

        let lines = captured.lock().expect("lock");
        assert_eq!(1, lines.len(), "expected one audit line");
        let json: serde_json::Value = serde_json::from_str(&lines[0]).expect("audit json");
        assert_eq!("backdoor_operation", json["event_type"].as_str().unwrap());
        assert_eq!("users_list", json["action"].as_str().unwrap());
        assert_eq!("success", json["outcome"].as_str().unwrap());
        assert_eq!("backdoor", json["resource_type"].as_str().unwrap());
        assert!(json.get("backdoor_token").is_none());
    }

    #[test]
    fn format_never_includes_sensitive_value_fields() {
        let line = format_security_audit_log(&SecurityAuditRecord::new(
            SecurityAuditEventType::ApiKeyRegenerate,
            Some(7),
        ));
        let json: serde_json::Value = serde_json::from_str(&line).expect("valid JSON");
        for forbidden in [
            "api_key",
            "session_id",
            "oauth_token",
            "access_token",
            "backdoor_token",
            "confirmation_token",
            "token",
            "secret",
            "X-Backdoor-Token",
        ] {
            assert!(
                json.get(forbidden).is_none(),
                "audit log must not include sensitive field {forbidden}: {line}"
            );
        }
        assert_eq!(
            "api_key_regenerate",
            json["event_type"].as_str().unwrap(),
            "event_type may name the event kind without exposing key material"
        );
    }

    #[test]
    fn api_key_event_types_are_distinct() {
        assert_ne!(
            SecurityAuditEventType::ApiKeyGenerate,
            SecurityAuditEventType::ApiKeyRegenerate
        );
    }
}
