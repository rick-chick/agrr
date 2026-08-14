//! Persisted learn handoff state (post-master payload, blueprint prefill, BP timing context).

use std::collections::BTreeMap;

use serde_json::Value;

#[derive(Debug, Clone, PartialEq, Default)]
pub struct LearnHandoffStateRead {
    pub post_master_payload: Option<Value>,
    pub bp_timing_apply_context: Option<Value>,
    pub blueprint_prefill_by_crop_id: BTreeMap<String, Value>,
}

impl LearnHandoffStateRead {
    pub fn is_empty(&self) -> bool {
        self.post_master_payload.is_none()
            && self.bp_timing_apply_context.is_none()
            && self.blueprint_prefill_by_crop_id.is_empty()
    }
}

#[derive(Debug, Clone, Default)]
pub struct LearnHandoffStatePatch {
    pub post_master_payload: Option<Option<Value>>,
    pub bp_timing_apply_context: Option<Option<Value>>,
    pub blueprint_prefill_crop_id: Option<i64>,
    pub blueprint_prefill_body: Option<Option<Value>>,
}

impl LearnHandoffStatePatch {
    pub fn has_updates(&self) -> bool {
        self.post_master_payload.is_some()
            || self.bp_timing_apply_context.is_some()
            || self.blueprint_prefill_crop_id.is_some()
    }
}
