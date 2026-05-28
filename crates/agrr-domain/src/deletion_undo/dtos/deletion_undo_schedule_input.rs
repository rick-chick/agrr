//! Ruby: `Domain::DeletionUndo::Dtos::DeletionUndoScheduleInput`

use std::collections::BTreeMap;

/// Ruby: `Domain::DeletionUndo::Dtos::DeletionUndoScheduleInput`
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DeletionUndoScheduleInput {
    pub resource_type: String,
    pub resource_id: Option<i64>,
    pub actor_id: Option<i64>,
    pub toast_message: Option<String>,
    pub auto_hide_after: Option<i64>,
    pub metadata: BTreeMap<String, String>,
    pub validate_before_schedule: bool,
}

impl DeletionUndoScheduleInput {
    pub fn new(
        resource_type: impl Into<String>,
        resource_id: Option<i64>,
        actor_id: Option<i64>,
        toast_message: Option<String>,
    ) -> Self {
        Self {
            resource_type: resource_type.into(),
            resource_id,
            actor_id,
            toast_message,
            auto_hide_after: None,
            metadata: BTreeMap::new(),
            validate_before_schedule: false,
        }
    }

    pub fn with_validate_before_schedule(mut self, validate: bool) -> Self {
        self.validate_before_schedule = validate;
        self
    }
}
