use serde_json::Value;

/// Ruby: `Domain::WorkRecord::Dtos::WorkRecordDestroyOutput`
#[derive(Debug, Clone, PartialEq)]
pub struct WorkRecordDestroyOutput {
    pub undo: Value,
}

impl WorkRecordDestroyOutput {
    pub fn new(undo: Value) -> Self {
        Self { undo }
    }
}
