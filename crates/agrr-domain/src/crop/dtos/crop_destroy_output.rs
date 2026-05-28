#[derive(Debug, Clone, PartialEq)]
pub struct CropDestroyOutput {
    pub undo: serde_json::Value,
}

impl CropDestroyOutput {
    pub fn new(undo: serde_json::Value) -> Self { Self { undo } }
}
