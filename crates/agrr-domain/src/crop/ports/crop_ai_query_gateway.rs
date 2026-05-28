use crate::crop::dtos::CropAiCreateFailure;
use serde_json::Value;

pub trait CropAiQueryGateway: Send + Sync {
    fn fetch_crop_json(&self, crop_name: &str) -> Result<Value, CropAiCreateFailure>;
}
