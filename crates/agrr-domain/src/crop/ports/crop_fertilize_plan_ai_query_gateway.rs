use crate::crop::dtos::CropBlueprintAiFailure;
use serde_json::Value;

/// Calls agrr `fertilize plan` CLI via daemon (Ruby: `FertilizeDaemonGateway#plan`).
pub trait CropFertilizePlanAiQueryGateway: Send + Sync {
    fn fetch_fertilize_plan(
        &self,
        crop_requirement: &Value,
        use_harvest_start: bool,
        max_applications: u32,
    ) -> Result<Value, CropBlueprintAiFailure>;
}
