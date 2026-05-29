use serde_json::{json, Value};

use crate::field_cultivation::dtos::ClimateCropEntity;

/// Builds agrr-shaped crop requirement JSON from a climate crop snapshot (no I/O).
pub fn from_climate_crop_entity(entity: &ClimateCropEntity) -> Value {
    json!({
        "crop": {
            "crop_id": entity.id.to_string(),
            "stages": entity.stages_for_mapper(),
        }
    })
}
