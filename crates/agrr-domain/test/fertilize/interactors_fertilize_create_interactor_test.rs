// Tests for `interactors/fertilize_create_interactor.rs` (Ruby parity under test/domain/fertilize/).

    use crate::fertilize::entities::{FertilizeEntity, FertilizeEntityAttrs};
    use crate::fertilize::gateways::FertilizeGateway;
    use crate::fertilize::ports::{CreateFailure, FertilizeCreateOutputPort};
    use crate::shared::attr::AttrMap;
    use crate::shared::exceptions::RecordInvalidError;
    use crate::shared::gateways::UserLookupGateway;
    use crate::shared::ports::translator_port::{TranslateOptions, TranslatorPort};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            format!("t:{key}")
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct OkGateway {
        entity: FertilizeEntity,
    }

    struct NameRequiredGateway;

    impl FertilizeGateway for NameRequiredGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            Err(Box::new(RecordInvalidError::new(
                Some("name is required".into()),
                None,
            )))
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<
            crate::fertilize::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    impl FertilizeGateway for OkGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.entity.clone())
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<
            crate::fertilize::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyOutput {
        success: Option<FertilizeEntity>,
        failure: Option<CreateFailure>,
    }

    impl FertilizeCreateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: FertilizeEntity) {
            self.success = Some(entity);
        }
        fn on_failure(&mut self, error: CreateFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_entity() -> FertilizeEntity {
        FertilizeEntity::new(FertilizeEntityAttrs {
            id: Some(1),
            user_id: Some(1),
            name: "Test".into(),
            n: Some(10.0),
            p: Some(5.0),
            k: Some(3.0),
            description: None,
            package_size: None,
            region: None,
            is_reference: false,
            created_at: None,
            updated_at: None,
        })
        .expect("valid")
    }

    // Ruby: test "creates fertilize for a regular user and passes the entity to on_success"
    #[test]
    fn creates_for_regular_user() {
        let entity = sample_entity();
        let gateway = OkGateway {
            entity: entity.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor = FertilizeCreateInteractor::new(
            &mut output,
            1,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = FertilizeCreateInput {
            name: "Test".into(),
            n: Some(10.0),
            p: Some(5.0),
            k: Some(3.0),
            region: Some("Kyoto".into()),
            ..FertilizeCreateInput::new("Test")
        };
        interactor.call(input).expect("handled");
        assert!(output.success.is_some());
        assert!(output.failure.is_none());
    }

    // Ruby: test "creates a reference fertilize for an admin user"
    #[test]
    fn creates_reference_fertilize_for_admin_user() {
        let entity = sample_entity();
        let gateway = OkGateway {
            entity: entity.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(2, true));
        let mut interactor = FertilizeCreateInteractor::new(
            &mut output,
            2,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = FertilizeCreateInput {
            is_reference: Some(true),
            ..FertilizeCreateInput::new("Reference")
        };
        interactor.call(input).expect("handled");
        assert!(output.success.is_some());
        assert!(output.failure.is_none());
    }

    struct PolicyDeniedGateway;
    impl FertilizeGateway for PolicyDeniedGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            Err(Box::new(PolicyPermissionDenied))
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<
            crate::fertilize::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    // Ruby: test "calls on_failure with the policy exception when the gateway denies permission"
    #[test]
    fn calls_on_failure_with_policy_exception_when_gateway_denies_permission() {
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor = FertilizeCreateInteractor::new(
            &mut output,
            1,
            &PolicyDeniedGateway,
            &StubTranslator,
            &lookup,
        );
        interactor
            .call(FertilizeCreateInput::new("X"))
            .expect("handled");
        assert!(matches!(
            output.failure,
            Some(CreateFailure::Policy(PolicyPermissionDenied))
        ));
    }

    struct BadRecordGateway;
    impl FertilizeGateway for BadRecordGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            Err(Box::new(RecordInvalidError::new(Some("bad".into()), None)))
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<
            crate::fertilize::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    // Ruby: test "calls on_failure with Error when create raises RecordInvalid"
    #[test]
    fn calls_on_failure_with_error_when_create_raises_record_invalid() {
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor = FertilizeCreateInteractor::new(
            &mut output,
            1,
            &BadRecordGateway,
            &StubTranslator,
            &lookup,
        );
        let input = FertilizeCreateInput {
            n: Some(1.0),
            p: Some(1.0),
            k: Some(1.0),
            region: Some("R".into()),
            ..FertilizeCreateInput::new("Test")
        };
        interactor.call(input).expect("handled");
        match output.failure {
            Some(CreateFailure::Error(err)) => assert_eq!(err.message, "bad"),
            other => panic!("expected Error, got {other:?}"),
        }
    }

    struct BoomGateway;
    impl FertilizeGateway for BoomGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            Err("Name can't be blank".into())
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<
            crate::fertilize::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    // Ruby: test "re-raises unexpected gateway errors"
    #[test]
    fn re_raises_unexpected_gateway_errors() {
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor = FertilizeCreateInteractor::new(
            &mut output,
            1,
            &BoomGateway,
            &StubTranslator,
            &lookup,
        );
        let err = interactor
            .call(FertilizeCreateInput::new("Test"))
            .unwrap_err();
        assert!(err.to_string().contains("Name can't be blank"));
    }

    struct NotFoundGateway;
    impl FertilizeGateway for NotFoundGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &User,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!("gateway must not be reached when the user is missing")
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<
            crate::fertilize::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<FertilizeEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct MissingUserLookup;
    impl UserLookupGateway for MissingUserLookup {
        fn find(&self, _: i64) -> User {
            panic!("User not found")
        }
    }

    // Ruby: test "calls on_failure when the user cannot be resolved"
    #[test]
    #[should_panic(expected = "User not found")]
    fn calls_on_failure_when_the_user_cannot_be_resolved() {
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let mut interactor = FertilizeCreateInteractor::new(
            &mut output,
            1,
            &NotFoundGateway,
            &StubTranslator,
            &MissingUserLookup,
        );
        let _ = interactor.call(FertilizeCreateInput::new("X"));
    }

    #[test]
    // Ruby: test "rejects a reference fertilize requested by a non-admin user"
    fn rejects_reference_for_non_admin() {
        let gateway = OkGateway {
            entity: sample_entity(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(1, false));
        let mut interactor = FertilizeCreateInteractor::new(
            &mut output,
            1,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = FertilizeCreateInput {
            is_reference: Some(true),
            ..FertilizeCreateInput::new("Reference")
        };
        interactor.call(input).expect("handled");
        assert!(output.success.is_none());
        match output.failure {
            Some(CreateFailure::Error(e)) => {
                assert_eq!(e.message, "t:fertilizes.flash.reference_only_admin");
            }
            other => panic!("expected Error, got {other:?}"),
        }
    }

    // Gateway: create_for_user without name → RecordInvalid "name is required"
    #[test]
    fn returns_error_when_create_without_name() {
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(7, false));
        let mut interactor = FertilizeCreateInteractor::new(
            &mut output,
            7,
            &NameRequiredGateway,
            &StubTranslator,
            &lookup,
        );
        interactor
            .call(FertilizeCreateInput::new(""))
            .expect("handled");
        match output.failure {
            Some(CreateFailure::Error(err)) => {
                assert_eq!(err.message, "name is required");
            }
            other => panic!("expected failure, got {other:?}"),
        }
    }
