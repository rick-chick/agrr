//! Ruby: `Domain::DeletionUndo::Interactors::DeletionUndoScheduleSuccessPayloadInteractor`

use crate::deletion_undo::dtos::{
    DeletionUndoSchedulePayloadFailure, DeletionUndoScheduleSuccessOutput,
};
use crate::deletion_undo::ports::DeletionUndoScheduleSuccessPayloadOutputPort;
use crate::deletion_undo::scheduled_undo_snapshot::ScheduledUndoSnapshot;
use crate::shared::hash::{blank_attr, present_attr};
use crate::shared::attr::AttrValue;
use crate::shared::ports::LoggerPort;

/// Ruby: `Domain::DeletionUndo::Interactors::DeletionUndoScheduleSuccessPayloadInteractor`
pub struct DeletionUndoScheduleSuccessPayloadInteractor<'a, O> {
    output_port: &'a mut O,
    logger: Option<&'a dyn LoggerPort>,
}

impl<'a, O> DeletionUndoScheduleSuccessPayloadInteractor<'a, O>
where
    O: DeletionUndoScheduleSuccessPayloadOutputPort,
{
    pub fn new(output_port: &'a mut O, logger: Option<&'a dyn LoggerPort>) -> Self {
        Self {
            output_port,
            logger,
        }
    }

    /// Ruby: `#call(snapshot)`
    pub fn call(&mut self, snapshot: &ScheduledUndoSnapshot) {
        if blank_attr(&AttrValue::Str(snapshot.undo_token.clone())) {
            if let Some(logger) = self.logger {
                logger.error(&format!(
                    "[DeletionUndo] Missing undo_token for {}#{}",
                    snapshot.resource_type.as_deref().unwrap_or("unknown"),
                    snapshot.resource_id.as_deref().unwrap_or("unknown")
                ));
            }
            self.output_port
                .on_failure(DeletionUndoSchedulePayloadFailure::missing_undo_token());
            return;
        }

        let resource_dom_id = compute_resource_dom_id(snapshot);
        let resource_label = snapshot.metadata.get("resource_label").cloned();

        self.output_port.on_success(DeletionUndoScheduleSuccessOutput::new(
            snapshot.undo_token.clone(),
            snapshot.metadata.get("undo_deadline").cloned(),
            snapshot.toast_message.clone(),
            snapshot.auto_hide_after,
            resource_label,
            resource_dom_id,
        ));
    }
}

fn compute_resource_dom_id(snapshot: &ScheduledUndoSnapshot) -> Option<String> {
    if let Some(stored) = snapshot.metadata.get("resource_dom_id") {
        if present_attr(&AttrValue::Str(stored.clone())) {
            return Some(stored.clone());
        }
    }

    let resource_type = snapshot.resource_type.as_deref()?;
    let resource_id = snapshot.resource_id.as_deref()?;
    if blank_attr(&AttrValue::Str(resource_type.to_string()))
        || blank_attr(&AttrValue::Str(resource_id.to_string()))
    {
        return None;
    }

    let base = resource_type
        .rsplit("::")
        .next()
        .unwrap_or(resource_type);
    let snake = camel_to_snake(base);
    Some(format!("{snake}_{resource_id}"))
}

fn camel_to_snake(name: &str) -> String {
    let mut out = String::new();
    for (i, ch) in name.chars().enumerate() {
        if ch.is_uppercase() {
            if i > 0 {
                out.push('_');
            }
            out.push(ch.to_ascii_lowercase());
        } else {
            out.push(ch);
        }
    }
    out.trim_start_matches('_').to_string()
}

#[cfg(test)]
mod interactors_deletion_undo_schedule_success_payload_interactor_test_inline {
    use super::*;
    include!(concat!(env!("CARGO_MANIFEST_DIR"), "/test/deletion_undo/interactors_deletion_undo_schedule_success_payload_interactor_test.rs"));
}
