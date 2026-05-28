/// Undo token entity is opaque at domain boundary (Ruby: undo entity from gateway).
#[derive(Debug, Clone)]
pub struct UndoEntity {
    pub raw: serde_json::Value,
}

/// Ruby: `Domain::AgriculturalTask::Dtos::AgriculturalTaskDestroyOutput`
#[derive(Debug, Clone)]
pub struct AgriculturalTaskDestroyOutput {
    pub undo: UndoEntity,
}

impl AgriculturalTaskDestroyOutput {
    pub fn new(undo: UndoEntity) -> Self {
        Self { undo }
    }
}
