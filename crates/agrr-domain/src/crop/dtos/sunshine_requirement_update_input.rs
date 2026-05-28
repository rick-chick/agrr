use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct SunshineRequirementUpdateInput {
    pub crop_id: i64,
    pub stage_id: i64,
    pub payload: Value,
}

impl SunshineRequirementUpdateInput {
    pub fn new(crop_id: i64, stage_id: i64, payload: Value) -> Self {
        Self { crop_id, stage_id, payload }
    }
}
