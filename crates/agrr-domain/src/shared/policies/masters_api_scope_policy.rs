//! API key scope enforcement for Masters JSON API (`masters:read` / `masters:write`).

use crate::shared::dtos::SessionPrincipal;

pub const MASTERS_READ_SCOPE: &str = "masters:read";
pub const MASTERS_WRITE_SCOPE: &str = "masters:write";

/// Required Masters API access derived from HTTP method and route shape.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MastersApiAccess {
    Read,
    Write,
    SetupProposalDryRun,
    SetupProposalApply,
}

impl MastersApiAccess {
    pub fn required_scope_label(self) -> &'static str {
        match self {
            MastersApiAccess::Read | MastersApiAccess::SetupProposalDryRun => MASTERS_READ_SCOPE,
            MastersApiAccess::Write | MastersApiAccess::SetupProposalApply => MASTERS_WRITE_SCOPE,
        }
    }
}

/// Ruby: `Domain::Shared::Policies::MastersApiScopePolicy`
pub struct MastersApiScopePolicy;

impl MastersApiScopePolicy {
    /// Session cookie auth (no per-key scopes) has full Masters access.
    pub fn allows(principal: &SessionPrincipal, access: MastersApiAccess) -> bool {
        match principal.api_key_scopes.as_ref() {
            None => true,
            Some(scopes) => Self::scopes_allow(scopes, access),
        }
    }

    pub fn scopes_allow(scopes: &[String], access: MastersApiAccess) -> bool {
        let has_read = scopes.iter().any(|s| s == MASTERS_READ_SCOPE);
        let has_write = scopes.iter().any(|s| s == MASTERS_WRITE_SCOPE);
        match access {
            MastersApiAccess::Read | MastersApiAccess::SetupProposalDryRun => has_read || has_write,
            MastersApiAccess::Write | MastersApiAccess::SetupProposalApply => has_write,
        }
    }
}

pub fn default_api_key_scopes() -> Vec<String> {
    vec![MASTERS_READ_SCOPE.into()]
}

pub fn full_api_key_scopes() -> Vec<String> {
    vec![MASTERS_READ_SCOPE.into(), MASTERS_WRITE_SCOPE.into()]
}

/// Normalizes a client request: always includes `masters:read`; adds write when requested.
pub fn normalize_requested_api_key_scopes(requested: Option<Vec<String>>) -> Vec<String> {
    let wants_write = requested
        .as_ref()
        .is_some_and(|scopes| scopes.iter().any(|s| s == MASTERS_WRITE_SCOPE));
    if wants_write {
        full_api_key_scopes()
    } else {
        default_api_key_scopes()
    }
}

pub fn parse_api_key_scopes_json(raw: Option<&str>) -> Option<Vec<String>> {
    let trimmed = raw.map(str::trim).unwrap_or("");
    if trimmed.is_empty() {
        return None;
    }
    serde_json::from_str(trimmed).ok()
}

pub fn serialize_api_key_scopes(scopes: &[String]) -> String {
    serde_json::to_string(scopes).expect("scopes JSON")
}

#[cfg(test)]
mod policies_masters_api_scope_policy_test_inline {
    use super::*;
    include!(concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/test/shared/policies_masters_api_scope_policy_test.rs"
    ));
}
