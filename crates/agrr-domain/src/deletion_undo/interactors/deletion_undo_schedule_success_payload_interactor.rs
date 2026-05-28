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
mod tests {
    use super::*;
    use crate::deletion_undo::dtos::DeletionUndoSchedulePayloadFailureReason;
    use crate::deletion_undo::scheduled_undo_snapshot::{ScheduledUndoSnapshot, ScheduledUndoSource};
    use std::collections::BTreeMap;

    struct StubUndo {
        undo_token: String,
        metadata: BTreeMap<String, String>,
        toast_message: Option<String>,
        auto_hide_after: i64,
        resource_type: Option<String>,
        resource_id: Option<String>,
    }

    impl ScheduledUndoSource for StubUndo {
        fn undo_token(&self) -> &str {
            &self.undo_token
        }

        fn metadata(&self) -> &BTreeMap<String, String> {
            &self.metadata
        }

        fn toast_message(&self) -> Option<&str> {
            self.toast_message.as_deref()
        }

        fn auto_hide_after(&self) -> i64 {
            self.auto_hide_after
        }

        fn resource_type(&self) -> Option<&str> {
            self.resource_type.as_deref()
        }

        fn resource_id(&self) -> Option<&str> {
            self.resource_id.as_deref()
        }
    }

    struct SpyOutput {
        success: Option<DeletionUndoScheduleSuccessOutput>,
        failure: Option<DeletionUndoSchedulePayloadFailure>,
    }

    impl DeletionUndoScheduleSuccessPayloadOutputPort for SpyOutput {
        fn on_success(&mut self, output: DeletionUndoScheduleSuccessOutput) {
            self.success = Some(output);
        }

        fn on_failure(&mut self, failure: DeletionUndoSchedulePayloadFailure) {
            self.failure = Some(failure);
        }
    }

    // Ruby: test "on_failure when undo_token is blank"
    #[test]
    fn on_failure_when_undo_token_is_blank() {
        let stub = StubUndo {
            undo_token: String::new(),
            metadata: BTreeMap::new(),
            toast_message: None,
            auto_hide_after: 5,
            resource_type: Some("Crop".into()),
            resource_id: Some("9".into()),
        };
        let snapshot = ScheduledUndoSnapshot::from_source(&stub);
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor = DeletionUndoScheduleSuccessPayloadInteractor::new(&mut output, None);
        interactor.call(&snapshot);

        let failure = output.failure.expect("on_failure");
        assert_eq!(
            failure.reason,
            DeletionUndoSchedulePayloadFailureReason::MissingUndoToken
        );
    }

    // Ruby: test "on_success uses metadata resource_dom_id when present"
    #[test]
    fn on_success_uses_metadata_resource_dom_id_when_present() {
        let stub = StubUndo {
            undo_token: "tok-a".into(),
            metadata: BTreeMap::from([
                ("undo_deadline".into(), "2026-05-01T00:00:00Z".into()),
                ("resource_label".into(), "Test crop".into()),
                ("resource_dom_id".into(), "custom_dom".into()),
                ("toast_message".into(), "from_md".into()),
            ]),
            toast_message: Some("toast".into()),
            auto_hide_after: 7,
            resource_type: Some("Crop".into()),
            resource_id: Some("3".into()),
        };
        let snapshot = ScheduledUndoSnapshot::from_source(&stub);
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor = DeletionUndoScheduleSuccessPayloadInteractor::new(&mut output, None);
        interactor.call(&snapshot);

        let success = output.success.expect("on_success");
        assert_eq!(success.undo_token, "tok-a");
        assert_eq!(
            success.undo_deadline.as_deref(),
            Some("2026-05-01T00:00:00Z")
        );
        assert_eq!(success.toast_message.as_deref(), Some("toast"));
        assert_eq!(success.auto_hide_after, 7);
        assert_eq!(success.resource_label.as_deref(), Some("Test crop"));
        assert_eq!(success.resource_dom_id.as_deref(), Some("custom_dom"));
    }

    // Ruby: test "on_success falls back to resource_type and resource_id for dom id"
    #[test]
    fn on_success_falls_back_to_resource_type_and_resource_id_for_dom_id() {
        let stub = StubUndo {
            undo_token: "tok-b".into(),
            metadata: BTreeMap::new(),
            toast_message: None,
            auto_hide_after: 5,
            resource_type: Some("CultivationPlan".into()),
            resource_id: Some("42".into()),
        };
        let snapshot = ScheduledUndoSnapshot::from_source(&stub);
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor = DeletionUndoScheduleSuccessPayloadInteractor::new(&mut output, None);
        interactor.call(&snapshot);

        let success = output.success.expect("on_success");
        assert_eq!(success.resource_dom_id.as_deref(), Some("cultivation_plan_42"));
    }
}
