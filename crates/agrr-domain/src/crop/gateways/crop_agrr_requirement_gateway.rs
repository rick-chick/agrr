use serde_json::Value;

/// Builds agrr crop-requirement JSON for a crop id.
pub trait CropAgrrRequirementGateway: Send + Sync {
    fn build_for_crop_id(
        &self,
        crop_id: i64,
    ) -> Result<Option<Value>, Box<dyn std::error::Error + Send + Sync>>;
}
