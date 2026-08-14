// Tests for `policies/plan_variance_learning_proposal_progress_policy.rs`.

use crate::cultivation_plan::policies::plan_variance_learning_proposal_progress_policy::validate_proposal_application_progress_updates;
use std::collections::BTreeMap;

#[test]
fn accepts_valid_statuses() {
    let mut updates = BTreeMap::new();
    updates.insert("stage_gdd:1:2".into(), "confirmed".into());
    updates.insert("bp_timing:3:general".into(), "dismissed".into());
    assert!(validate_proposal_application_progress_updates(&updates).is_ok());
}

#[test]
fn rejects_empty_proposal_key() {
    let mut updates = BTreeMap::new();
    updates.insert("   ".into(), "confirmed".into());
    let err = validate_proposal_application_progress_updates(&updates).expect_err("blank key");
    assert_eq!(err.detail_message(), Some("proposal_key is required"));
}

#[test]
fn rejects_invalid_status() {
    let mut updates = BTreeMap::new();
    updates.insert("stage_gdd:1:2".into(), "invalid_status".into());
    let err = validate_proposal_application_progress_updates(&updates).expect_err("bad status");
    assert_eq!(err.detail_message(), Some("invalid proposal status"));
}

#[test]
fn accepts_all_valid_status_values() {
    for status in [
        "not_started",
        "applied_pending_confirmation",
        "confirmed",
        "done",
        "dismissed",
    ] {
        let mut updates = BTreeMap::new();
        updates.insert("stage_gdd:1:2".into(), status.into());
        assert!(
            validate_proposal_application_progress_updates(&updates).is_ok(),
            "status {status} should be valid"
        );
    }
}
