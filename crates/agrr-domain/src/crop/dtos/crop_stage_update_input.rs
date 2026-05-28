use serde_json::Value;

/// Ruby: `Domain::Crop::Dtos::CropStageUpdateInput`
#[derive(Debug, Clone, PartialEq)]
pub struct CropStageUpdateInput {
    pub crop_stage_id: i64,
    pub payload: Value,
}
