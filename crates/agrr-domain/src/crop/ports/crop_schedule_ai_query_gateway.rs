use crate::crop::dtos::CropBlueprintAiFailure;
use serde_json::Value;

/// Calls agrr `schedule` CLI via daemon (Ruby: `ScheduleDaemonGateway#generate`).
pub trait CropScheduleAiQueryGateway: Send + Sync {
    fn generate_schedule(
        &self,
        crop_name: &str,
        variety: &str,
        stage_requirements: &Value,
        agricultural_tasks: &Value,
    ) -> Result<Value, CropBlueprintAiFailure>;
}
