//! Ruby: `Domain::DeletionUndo::Entities::DeletionUndoEntity`

use std::collections::BTreeMap;

use time::OffsetDateTime;

/// Ruby: `Domain::DeletionUndo::Entities::DeletionUndoEntity`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeletionUndoEntity {
    pub id: String,
    pub expires_at: OffsetDateTime,
    pub status: String,
    pub metadata: BTreeMap<String, String>,
}

impl DeletionUndoEntity {
    pub fn new(
        id: impl Into<String>,
        expires_at: OffsetDateTime,
        status: impl Into<String>,
        metadata: BTreeMap<String, String>,
    ) -> Self {
        Self {
            id: id.into(),
            expires_at,
            status: status.into(),
            metadata,
        }
    }

    /// Ruby: `#expired?(now:)`
    pub fn expired(&self, now: OffsetDateTime) -> bool {
        now > self.expires_at
    }

    pub fn scheduled(&self) -> bool {
        self.status == "scheduled"
    }

    pub fn restored(&self) -> bool {
        self.status == "restored"
    }

    pub fn failed(&self) -> bool {
        self.status == "failed"
    }

    pub fn undo_token(&self) -> &str {
        &self.id
    }

    pub fn toast_message(&self) -> Option<&str> {
        self.metadata.get("toast_message").map(String::as_str)
    }

    pub fn auto_hide_after(&self) -> i64 {
        self.metadata
            .get("auto_hide_after")
            .and_then(|s| s.parse().ok())
            .unwrap_or(5)
    }
}

#[cfg(test)]
mod entities_deletion_undo_entity_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/deletion_undo/entities_deletion_undo_entity_test.rs"));
}
