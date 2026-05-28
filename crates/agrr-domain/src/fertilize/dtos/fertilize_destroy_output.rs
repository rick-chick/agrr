/// Ruby: `Domain::Fertilize::Dtos::FertilizeDestroyOutput`
#[derive(Debug, Clone)]
pub struct FertilizeDestroyOutput {
    pub undo: serde_json::Value,
}

impl FertilizeDestroyOutput {
    pub fn new(undo: serde_json::Value) -> Self {
        Self { undo }
    }
}
