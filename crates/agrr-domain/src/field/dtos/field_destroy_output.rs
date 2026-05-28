use serde_json::Value;

/// Ruby: `Domain::Field::Dtos::FieldDestroyOutput`
#[derive(Debug, Clone, PartialEq)]
pub struct FieldDestroyOutput {
    pub undo: Value,
}

impl FieldDestroyOutput {
    pub fn new(undo: Value) -> Self {
        Self { undo }
    }
}
