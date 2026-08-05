use super::*;

#[test]
fn read_scope_allows_get_and_dry_run() {
    let scopes = default_api_key_scopes();
    assert!(MastersApiScopePolicy::scopes_allow(&scopes, MastersApiAccess::Read));
    assert!(MastersApiScopePolicy::scopes_allow(&scopes, MastersApiAccess::SetupProposalDryRun));
}

#[test]
fn read_scope_denies_write_and_apply() {
    let scopes = default_api_key_scopes();
    assert!(!MastersApiScopePolicy::scopes_allow(&scopes, MastersApiAccess::Write));
    assert!(!MastersApiScopePolicy::scopes_allow(&scopes, MastersApiAccess::SetupProposalApply));
}

#[test]
fn write_scope_allows_all_masters_access() {
    let scopes = full_api_key_scopes();
    assert!(MastersApiScopePolicy::scopes_allow(&scopes, MastersApiAccess::Read));
    assert!(MastersApiScopePolicy::scopes_allow(&scopes, MastersApiAccess::Write));
    assert!(MastersApiScopePolicy::scopes_allow(&scopes, MastersApiAccess::SetupProposalDryRun));
    assert!(MastersApiScopePolicy::scopes_allow(&scopes, MastersApiAccess::SetupProposalApply));
}

#[test]
fn session_principal_without_scopes_allows_all() {
    let principal = SessionPrincipal {
        id: 1,
        email: "u@example.com".into(),
        name: "u".into(),
        admin: false,
        anonymous: false,
        api_key_scopes: None,
    };
    assert!(MastersApiScopePolicy::allows(&principal, MastersApiAccess::Write));
}

#[test]
fn normalize_requested_scopes_defaults_to_read_only() {
    assert_eq!(default_api_key_scopes(), normalize_requested_api_key_scopes(None));
    assert_eq!(
        default_api_key_scopes(),
        normalize_requested_api_key_scopes(Some(vec!["masters:read".into()]))
    );
}

#[test]
fn normalize_requested_scopes_adds_write_when_requested() {
    assert_eq!(
        full_api_key_scopes(),
        normalize_requested_api_key_scopes(Some(vec![MASTERS_WRITE_SCOPE.into()]))
    );
}
