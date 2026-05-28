/// Ruby: `Domain::Pest::Dtos::PestDestroyOutput`
#[derive(Debug, Clone)]
pub struct PestDestroyOutput {
    pub undo: serde_json::Value,
}

impl PestDestroyOutput {
    pub fn new(undo: serde_json::Value) -> Self {
        Self { undo }
    }
}
