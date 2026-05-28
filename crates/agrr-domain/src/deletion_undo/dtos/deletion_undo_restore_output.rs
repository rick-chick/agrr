//! Ruby: `Domain::DeletionUndo::Dtos::DeletionUndoRestoreOutput`

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeletionUndoRestoreOutput {
    pub status: String,
    pub undo_token: String,
}

impl DeletionUndoRestoreOutput {
    pub fn new(status: impl Into<String>, undo_token: impl Into<String>) -> Self {
        Self {
            status: status.into(),
            undo_token: undo_token.into(),
        }
    }
}
