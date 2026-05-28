/// Ruby: `Domain::Pesticide::Dtos::PesticideDestroyOutput`
#[derive(Debug, Clone, PartialEq)]
pub struct PesticideDestroyOutput {
    pub undo: serde_json::Value,
}

impl PesticideDestroyOutput {
    pub fn new(undo: serde_json::Value) -> Self {
        Self { undo }
    }
}
