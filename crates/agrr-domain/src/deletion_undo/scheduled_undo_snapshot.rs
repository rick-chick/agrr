//! Ruby: `Domain::DeletionUndo::ScheduledUndoSnapshot`

use std::collections::BTreeMap;

/// Ruby: `Domain::DeletionUndo::ScheduledUndoSnapshot`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScheduledUndoSnapshot {
    pub undo_token: String,
    pub metadata: BTreeMap<String, String>,
    pub toast_message: Option<String>,
    pub auto_hide_after: i64,
    pub resource_type: Option<String>,
    pub resource_id: Option<String>,
}

/// Source for [`ScheduledUndoSnapshot::from`].
pub trait ScheduledUndoSource {
    fn undo_token(&self) -> &str;
    fn metadata(&self) -> &BTreeMap<String, String>;
    fn toast_message(&self) -> Option<&str>;
    fn auto_hide_after(&self) -> i64;
    fn resource_type(&self) -> Option<&str>;
    fn resource_id(&self) -> Option<&str>;
}

impl ScheduledUndoSnapshot {
    pub fn new(
        undo_token: impl Into<String>,
        metadata: BTreeMap<String, String>,
        toast_message: Option<String>,
        auto_hide_after: i64,
        resource_type: Option<String>,
        resource_id: Option<String>,
    ) -> Self {
        Self {
            undo_token: undo_token.into(),
            metadata,
            toast_message,
            auto_hide_after,
            resource_type,
            resource_id,
        }
    }

    /// Ruby: `.from(scheduled_undo)`
    pub fn from_source(source: &dyn ScheduledUndoSource) -> Self {
        Self {
            undo_token: source.undo_token().to_string(),
            metadata: source.metadata().clone(),
            toast_message: source.toast_message().map(str::to_string),
            auto_hide_after: source.auto_hide_after(),
            resource_type: source.resource_type().map(str::to_string),
            resource_id: source.resource_id().map(str::to_string),
        }
    }
}
