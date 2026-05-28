use serde_json::Value;
use time::Date;

use crate::field_cultivation::dtos::ClimateCropEntity;

/// Ruby: `FieldCultivationClimateProgressGateway`
pub trait FieldCultivationClimateProgressGateway: Send + Sync {
    fn calculate_progress(
        &self,
        crop_entity: &ClimateCropEntity,
        start_date: Date,
        weather_payload: &Value,
    ) -> Value;
}
