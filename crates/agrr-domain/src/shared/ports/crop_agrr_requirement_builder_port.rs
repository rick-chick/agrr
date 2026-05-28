use serde_json::Value;

/// Adapter-bound crop source (Ruby: duck-typed `crop_source` with `to_agrr_requirement` or AR Crop).
pub trait CropAgrrRequirementSource: Send + Sync {}

/// Ruby: `Domain::Shared::Ports::CropAgrrRequirementBuilderPort`
pub trait CropAgrrRequirementBuilderPort: Send + Sync {
    /// Ruby: `#build_from(crop_source)` — agrr CLI crop-requirement-file shape (string keys).
    fn build_from(&self, crop_source: &dyn CropAgrrRequirementSource) -> Value;
}
