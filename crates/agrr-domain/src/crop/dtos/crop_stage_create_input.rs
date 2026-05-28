use serde_json::Value;

/// Ruby: `Domain::Crop::Dtos::CropStageCreateInput`
#[derive(Debug, Clone, PartialEq)]
pub struct CropStageCreateInput {
    pub crop_id: i64,
    pub payload: Value,
}

impl CropStageCreateInput {
    pub fn new(crop_id: i64, payload: Value) -> Self {
        Self { crop_id, payload }
    }
}
