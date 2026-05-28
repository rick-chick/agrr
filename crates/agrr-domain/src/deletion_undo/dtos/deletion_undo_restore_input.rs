//! Ruby: `Domain::DeletionUndo::Dtos::DeletionUndoRestoreInput`

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeletionUndoRestoreInput {
    pub undo_token: String,
}

impl DeletionUndoRestoreInput {
    pub fn new(undo_token: impl Into<String>) -> Self {
        Self {
            undo_token: undo_token.into(),
        }
    }
}
