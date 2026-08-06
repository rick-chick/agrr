//! API key scopes for Masters API access control.

/// Scope string stored on `users.api_key_scopes` (JSON array).
pub const MASTERS_READ: &str = "masters:read";
pub const MASTERS_WRITE: &str = "masters:write";

/// Required Masters API access derived from HTTP method and path/query.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MastersApiAccessRequirement {
    Read,
    Write,
}

impl MastersApiAccessRequirement {
    /// Classify a Masters API request (path must be under `/api/v1/masters/`).
    pub fn from_http(method: &str, path: &str, query: Option<&str>) -> Option<Self> {
        if !path.starts_with("/api/v1/masters/") {
            return None;
        }
        if path.contains("/setup_proposal") {
            let query = query.unwrap_or("");
            if query.contains("mode=apply") {
                return Some(Self::Write);
            }
            if query.contains("mode=dry_run") {
                return Some(Self::Read);
            }
        }
        match method {
            "GET" | "HEAD" => Some(Self::Read),
            "POST" | "PUT" | "PATCH" | "DELETE" => Some(Self::Write),
            _ => None,
        }
    }
}

/// Returns whether `scopes` grant the required Masters API access.
pub fn masters_api_scope_allows(scopes: &[String], requirement: MastersApiAccessRequirement) -> bool {
    let has_read = scopes.iter().any(|s| s == MASTERS_READ);
    let has_write = scopes.iter().any(|s| s == MASTERS_WRITE);
    match requirement {
        MastersApiAccessRequirement::Read => has_read || has_write,
        MastersApiAccessRequirement::Write => has_write,
    }
}

/// Default scopes for newly generated API keys (least privilege).
pub fn default_api_key_scopes_json() -> String {
    format!(r#"["{MASTERS_READ}"]"#)
}

/// Parse JSON array of scope strings; ignores unknown entries.
pub fn parse_api_key_scopes_json(raw: Option<&str>) -> Vec<String> {
    let Some(raw) = raw.filter(|s| !s.trim().is_empty()) else {
        return Vec::new();
    };
    let Ok(value) = serde_json::from_str::<serde_json::Value>(raw) else {
        return Vec::new();
    };
    value
        .as_array()
        .into_iter()
        .flatten()
        .filter_map(|v| v.as_str().map(str::to_string))
        .collect()
}

#[cfg(test)]
mod masters_api_scope_test_inline {
    use super::*;

    #[test]
    fn from_http_classifies_read_write_and_apply() {
        assert_eq!(
            MastersApiAccessRequirement::from_http(
                "POST",
                "/api/v1/masters/crops/1/setup_proposal",
                Some("mode=apply")
            ),
            Some(MastersApiAccessRequirement::Write)
        );
        assert_eq!(
            MastersApiAccessRequirement::from_http(
                "POST",
                "/api/v1/masters/crops/1/setup_proposal",
                Some("mode=dry_run")
            ),
            Some(MastersApiAccessRequirement::Read)
        );
        assert_eq!(
            MastersApiAccessRequirement::from_http("GET", "/api/v1/masters/crops", None),
            Some(MastersApiAccessRequirement::Read)
        );
        assert_eq!(
            MastersApiAccessRequirement::from_http("POST", "/api/v1/masters/crops", None),
            Some(MastersApiAccessRequirement::Write)
        );
    }

    #[test]
    fn scope_allows_read_with_read_or_write() {
        assert!(masters_api_scope_allows(
            &[MASTERS_READ.into()],
            MastersApiAccessRequirement::Read
        ));
        assert!(masters_api_scope_allows(
            &[MASTERS_WRITE.into()],
            MastersApiAccessRequirement::Read
        ));
        assert!(!masters_api_scope_allows(
            &[MASTERS_READ.into()],
            MastersApiAccessRequirement::Write
        ));
        assert!(masters_api_scope_allows(
            &[MASTERS_READ.into(), MASTERS_WRITE.into()],
            MastersApiAccessRequirement::Write
        ));
    }

    #[test]
    fn parse_api_key_scopes_json_handles_array() {
        assert_eq!(
            parse_api_key_scopes_json(Some(r#"["masters:read","masters:write"]"#)),
            vec!["masters:read".to_string(), "masters:write".to_string()]
        );
        assert!(parse_api_key_scopes_json(None).is_empty());
    }
}
