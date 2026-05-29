// Tests for `interactors/deletion_undo_schedule_interactor.rs` (Ruby parity under test/domain/deletion_undo/).

    use crate::deletion_undo::dtos::DeletionUndoScheduleFailureReason;
    use crate::deletion_undo::entities::DeletionUndoEntity;
    use crate::deletion_undo::schedule_authorization::SchedulableRecord;
    use crate::shared::user::User;
    use std::collections::BTreeMap;
    use time::macros::datetime;

    struct SpyOutput {
        success: Option<DeletionUndoEntity>,
        failure: Option<DeletionUndoScheduleFailure>,
    }

    impl DeletionUndoScheduleOutputPort for SpyOutput {
        fn on_success(&mut self, entity: DeletionUndoEntity) {
            self.success = Some(entity);
        }

        fn on_failure(&mut self, failure: DeletionUndoScheduleFailure) {
            self.failure = Some(failure);
        }
    }

    struct MockUserLookup {
        user: User,
    }

    impl ActorLookupPort for MockUserLookup {
        fn find(&self, _actor_id: Option<i64>) -> Result<User, crate::shared::exceptions::RecordNotFoundError> {
            Ok(self.user)
        }
    }

    #[derive(Clone)]
    enum ScheduleBehavior {
        Return(DeletionUndoEntity),
        ErrUndoSystem,
        ErrRecordInvalid,
        ErrAssociationInUse,
        Unconfigured,
    }

    #[derive(Clone)]
    struct MockGateway {
        record: SchedulableRecord,
        behavior: ScheduleBehavior,
        last_validate: std::sync::Arc<std::sync::atomic::AtomicBool>,
        expected_resource_type: String,
        expected_resource_id: i64,
    }

    impl DeletionUndoGateway for MockGateway {
        fn find_by_token(
            &self,
            _undo_token: &str,
        ) -> Result<DeletionUndoEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn expire_if_needed(
            &self,
            _event_id: &str,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn perform_restore(
            &self,
            _event_id: &str,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn mark_failed(
            &self,
            _event_id: &str,
            _error_message: &str,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_schedulable_record(
            &self,
            _resource_type: &str,
            _resource_id: i64,
        ) -> Result<SchedulableRecord, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.record.clone())
        }

        fn schedule(
            &self,
            resource_type: &str,
            resource_id: i64,
            _actor_id: Option<i64>,
            _toast_message: Option<&str>,
            _auto_hide_after: Option<i64>,
            _metadata: &BTreeMap<String, String>,
            validate_before_schedule: bool,
        ) -> Result<DeletionUndoEntity, Box<dyn std::error::Error + Send + Sync>> {
            self.last_validate.store(
                validate_before_schedule,
                std::sync::atomic::Ordering::SeqCst,
            );
            assert_eq!(resource_type, self.expected_resource_type);
            assert_eq!(resource_id, self.expected_resource_id);
            match &self.behavior {
                ScheduleBehavior::Return(entity) => Ok(entity.clone()),
                ScheduleBehavior::ErrUndoSystem => {
                    Err(Box::new(DeletionUndoError("tok".into())))
                }
                ScheduleBehavior::ErrRecordInvalid => Err(Box::new(RecordInvalidError::new(
                    Some("invalid record".into()),
                    None,
                ))),
                ScheduleBehavior::ErrAssociationInUse => Err(Box::new(AssociationInUseError)),
                ScheduleBehavior::Unconfigured => panic!("schedule should not be called"),
            }
        }
    }

    fn sample_entity() -> DeletionUndoEntity {
        DeletionUndoEntity::new(
            "evt-1",
            datetime!(2026-01-01 2:00:00 UTC),
            "scheduled",
            BTreeMap::from([("toast_message".into(), "x".into())]),
        )
    }

    fn build_interactor<'a>(
        output: &'a mut SpyOutput,
        gateway: &'a MockGateway,
        user_lookup: &'a MockUserLookup,
    ) -> DeletionUndoScheduleInteractor<'a, MockGateway, SpyOutput, MockUserLookup> {
        DeletionUndoScheduleInteractor::new(output, gateway, user_lookup)
    }

    // Ruby: test "calls on_success with entity when gateway schedules"
    #[test]
    fn calls_on_success_with_entity_when_gateway_schedules() {
        let entity = sample_entity();
        let gateway = MockGateway {
            record: SchedulableRecord::crop(1, false),
            behavior: ScheduleBehavior::Return(entity.clone()),
            last_validate: std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false)),
            expected_resource_type: "Crop".into(),
            expected_resource_id: 9,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(1, true),
        };
        let mut interactor = build_interactor(&mut output, &gateway, &user_lookup);

        let input = DeletionUndoScheduleInput::new("Crop", Some(9), None, Some("removed".into()));
        interactor.call(input).expect("call succeeds");

        assert_eq!(output.success.as_ref(), Some(&entity));
    }

    // Ruby: test "maps Domain::DeletionUndo::Exceptions::DeletionUndoError to undo_system_error failure"
    #[test]
    fn maps_deletion_undo_error_to_undo_system_error_failure() {
        let gateway = MockGateway {
            record: SchedulableRecord::crop(1, false),
            behavior: ScheduleBehavior::ErrUndoSystem,
            last_validate: std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false)),
            expected_resource_type: "Crop".into(),
            expected_resource_id: 1,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(1, true),
        };
        let mut interactor = build_interactor(&mut output, &gateway, &user_lookup);

        let input = DeletionUndoScheduleInput::new("Crop", Some(1), None, Some("removed".into()));
        interactor.call(input).expect("call succeeds");

        let failure = output.failure.expect("on_failure");
        assert_eq!(
            failure.reason,
            DeletionUndoScheduleFailureReason::UndoSystemError
        );
        assert_eq!(failure.detail_message.as_deref(), Some("tok"));
    }

    // Ruby: test "maps shared RecordInvalid to validation_error"
    #[test]
    fn maps_shared_record_invalid_to_validation_error() {
        let gateway = MockGateway {
            record: SchedulableRecord::crop(1, false),
            behavior: ScheduleBehavior::ErrRecordInvalid,
            last_validate: std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false)),
            expected_resource_type: "Crop".into(),
            expected_resource_id: 2,
        };
        let last_validate = gateway.last_validate.clone();
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(1, true),
        };
        let mut interactor = build_interactor(&mut output, &gateway, &user_lookup);

        let input = DeletionUndoScheduleInput::new("Crop", Some(2), None, Some("removed".into()))
            .with_validate_before_schedule(true);
        interactor.call(input).expect("call succeeds");

        let failure = output.failure.expect("on_failure");
        assert_eq!(
            failure.reason,
            DeletionUndoScheduleFailureReason::ValidationError
        );
        assert_eq!(
            failure.detail_message.as_deref(),
            Some("invalid record")
        );
        assert!(last_validate.load(std::sync::atomic::Ordering::SeqCst));
    }

    // Ruby: test "maps shared AssociationInUse to association_in_use"
    #[test]
    fn maps_shared_association_in_use_to_association_in_use() {
        let gateway = MockGateway {
            record: SchedulableRecord {
                type_name: "Pest".into(),
                is_reference: false,
                user_id: Some(7),
                ..SchedulableRecord::crop(7, false)
            },
            behavior: ScheduleBehavior::ErrAssociationInUse,
            last_validate: std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false)),
            expected_resource_type: "Pest".into(),
            expected_resource_id: 3,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(7, true),
        };
        let mut interactor = build_interactor(&mut output, &gateway, &user_lookup);

        let input = DeletionUndoScheduleInput::new("Pest", Some(3), Some(7), Some("removed".into()));
        interactor.call(input).expect("call succeeds");

        let failure = output.failure.expect("on_failure");
        assert_eq!(
            failure.reason,
            DeletionUndoScheduleFailureReason::AssociationInUse
        );
        assert_eq!(failure.detail_message.as_deref(), Some("association in use"));
    }

    // Ruby: test "passes validate_before_schedule false to gateway"
    #[test]
    fn passes_validate_before_schedule_false_to_gateway() {
        let entity = DeletionUndoEntity::new(
            "evt-1",
            datetime!(2026-01-01 2:00:00 UTC),
            "scheduled",
            BTreeMap::new(),
        );
        let gateway = MockGateway {
            record: SchedulableRecord {
                type_name: "Farm".into(),
                is_reference: false,
                user_id: Some(1),
                ..SchedulableRecord::crop(1, false)
            },
            behavior: ScheduleBehavior::Return(entity.clone()),
            last_validate: std::sync::Arc::new(std::sync::atomic::AtomicBool::new(true)),
            expected_resource_type: "Farm".into(),
            expected_resource_id: 11,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(1, true),
        };
        let mut interactor = build_interactor(&mut output, &gateway, &user_lookup);

        let input = DeletionUndoScheduleInput::new("Farm", Some(11), None, Some("removed".into()));
        interactor.call(input).expect("call succeeds");

        assert_eq!(output.success.as_ref(), Some(&entity));
        assert!(!gateway.last_validate.load(std::sync::atomic::Ordering::SeqCst));
    }

    // Ruby: test "raises ArgumentError when resource_type is blank"
    #[test]
    fn raises_argument_error_when_resource_type_is_blank() {
        let gateway = MockGateway {
            record: SchedulableRecord::crop(1, false),
            behavior: ScheduleBehavior::Unconfigured,
            last_validate: std::sync::Arc::new(std::sync::atomic::AtomicBool::new(false)),
            expected_resource_type: String::new(),
            expected_resource_id: 0,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(1, true),
        };
        let mut interactor = build_interactor(&mut output, &gateway, &user_lookup);

        let input = DeletionUndoScheduleInput::new("", Some(1), None, Some("x".into()));
        let err = interactor.call(input).expect_err("ArgumentError");
        assert!(err.0.contains("resource_type"));
    }
