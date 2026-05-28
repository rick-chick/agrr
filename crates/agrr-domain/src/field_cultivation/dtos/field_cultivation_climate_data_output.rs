use serde_json::Value;

#[derive(Debug, Clone, PartialEq)]
pub struct FieldCultivationClimateDataOutput {
    pub field_cultivation: Value,
    pub farm: Value,
    pub crop_requirements: Value,
    pub weather_data: Vec<Value>,
    pub gdd_data: Vec<Value>,
    pub stages: Vec<Value>,
    pub progress_result: Value,
    pub debug_info: Value,
}
