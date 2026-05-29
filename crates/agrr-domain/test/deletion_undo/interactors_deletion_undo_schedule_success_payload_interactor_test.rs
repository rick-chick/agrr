// Tests for `interactors/deletion_undo_schedule_success_payload_interactor.rs` (Ruby parity under test/domain/deletion_undo/).

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
