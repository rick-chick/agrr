/// Ruby: `Domain::Farm::Dtos::FarmDestroyOutput`
#[derive(Debug, Clone, PartialEq)]
pub struct FarmDestroyOutput {
    pub undo: serde_json::Value,
    pub farm_name: String,
}

impl FarmDestroyOutput {
    pub fn new(undo: serde_json::Value, farm_name: impl Into<String>) -> Self {
        Self {
            undo,
            farm_name: farm_name.into(),
        }
    }
}
