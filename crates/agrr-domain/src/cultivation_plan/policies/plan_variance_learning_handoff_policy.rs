//! Validates learn handoff patch payloads.

use crate::cultivation_plan::dtos::LearnHandoffStatePatch;
use crate::shared::exceptions::RecordInvalidError;

pub fn validate_learn_handoff_patch(patch: &LearnHandoffStatePatch) -> Result<(), RecordInvalidError> {
    if !patch.has_updates() {
        return Err(RecordInvalidError::new(
            Some("learn_handoff is required".into()),
            None,
        ));
    }

    if let Some(Some(payload)) = &patch.post_master_payload {
        if !payload.is_object() {
            return Err(RecordInvalidError::new(
                Some("post_master_payload must be an object".into()),
                None,
            ));
        }
    }

    if let Some(Some(context)) = &patch.bp_timing_apply_context {
        if !context.is_object() {
            return Err(RecordInvalidError::new(
                Some("bp_timing_apply_context must be an object".into()),
                None,
            ));
        }
    }

    if patch.blueprint_prefill_crop_id.is_some() {
        let crop_id = patch
            .blueprint_prefill_crop_id
            .expect("checked is_some");
        if crop_id <= 0 {
            return Err(RecordInvalidError::new(
                Some("blueprint_prefill crop_id must be positive".into()),
                None,
            ));
        }
        if let Some(Some(body)) = &patch.blueprint_prefill_body {
            if !body.is_object() {
                return Err(RecordInvalidError::new(
                    Some("blueprint_prefill body must be an object".into()),
                    None,
                ));
            }
        }
    }

    Ok(())
}
