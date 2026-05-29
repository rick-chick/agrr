use serde_json::Value;
use time::Date;

/// Ruby: `FieldCultivationClimateProgressGateway`
pub trait FieldCultivationClimateProgressGateway: Send + Sync {
    fn calculate_progress(
        &self,
        crop_requirement: &Value,
        start_date: Date,
        weather_payload: &Value,
    ) -> Value;
}
