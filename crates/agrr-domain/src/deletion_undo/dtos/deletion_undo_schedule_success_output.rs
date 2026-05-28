//! Ruby: `Domain::DeletionUndo::Dtos::DeletionUndoScheduleSuccessOutput`

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeletionUndoScheduleSuccessOutput {
    pub undo_token: String,
    pub undo_deadline: Option<String>,
    pub toast_message: Option<String>,
    pub auto_hide_after: i64,
    pub resource_label: Option<String>,
    pub resource_dom_id: Option<String>,
}

impl DeletionUndoScheduleSuccessOutput {
    #[allow(clippy::too_many_arguments)]
    pub fn new(
        undo_token: impl Into<String>,
        undo_deadline: Option<String>,
        toast_message: Option<String>,
        auto_hide_after: i64,
        resource_label: Option<String>,
        resource_dom_id: Option<String>,
    ) -> Self {
        Self {
            undo_token: undo_token.into(),
            undo_deadline,
            toast_message,
            auto_hide_after,
            resource_label,
            resource_dom_id,
        }
    }
}
