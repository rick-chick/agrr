// Tests for `policies/plan_variance_learning_handoff_policy.rs`.

use crate::cultivation_plan::dtos::LearnHandoffStatePatch;
use crate::cultivation_plan::policies::plan_variance_learning_handoff_policy::validate_learn_handoff_patch;
use serde_json::json;

fn patch_with_post_master() -> LearnHandoffStatePatch {
    LearnHandoffStatePatch {
        post_master_payload: Some(Some(json!({"kind": "stage_gdd", "cropId": 1}))),
        ..Default::default()
    }
}

#[test]
fn rejects_empty_patch_without_updates() {
    let patch = LearnHandoffStatePatch::default();
    let err = validate_learn_handoff_patch(&patch).expect_err("empty patch");
    assert_eq!(
        err.detail_message(),
        Some("learn_handoff is required")
    );
}

#[test]
fn accepts_valid_post_master_payload() {
    assert!(validate_learn_handoff_patch(&patch_with_post_master()).is_ok());
}

#[test]
fn rejects_non_object_post_master_payload() {
    let patch = LearnHandoffStatePatch {
        post_master_payload: Some(Some(json!("not-an-object"))),
        ..Default::default()
    };
    let err = validate_learn_handoff_patch(&patch).expect_err("non-object post_master");
    assert_eq!(
        err.detail_message(),
        Some("post_master_payload must be an object")
    );
}

#[test]
fn rejects_non_object_bp_timing_apply_context() {
    let patch = LearnHandoffStatePatch {
        bp_timing_apply_context: Some(Some(json!([]))),
        ..Default::default()
    };
    let err = validate_learn_handoff_patch(&patch).expect_err("non-object bp context");
    assert_eq!(
        err.detail_message(),
        Some("bp_timing_apply_context must be an object")
    );
}

#[test]
fn rejects_non_positive_blueprint_prefill_crop_id() {
    let patch = LearnHandoffStatePatch {
        blueprint_prefill_crop_id: Some(0),
        ..Default::default()
    };
    let err = validate_learn_handoff_patch(&patch).expect_err("zero crop_id");
    assert_eq!(
        err.detail_message(),
        Some("blueprint_prefill crop_id must be positive")
    );
}

#[test]
fn rejects_non_object_blueprint_prefill_body() {
    let patch = LearnHandoffStatePatch {
        blueprint_prefill_crop_id: Some(4),
        blueprint_prefill_body: Some(Some(json!("invalid"))),
        ..Default::default()
    };
    let err = validate_learn_handoff_patch(&patch).expect_err("non-object prefill body");
    assert_eq!(
        err.detail_message(),
        Some("blueprint_prefill body must be an object")
    );
}

#[test]
fn accepts_blueprint_prefill_with_crop_id_only() {
    let patch = LearnHandoffStatePatch {
        blueprint_prefill_crop_id: Some(4),
        ..Default::default()
    };
    assert!(validate_learn_handoff_patch(&patch).is_ok());
}
