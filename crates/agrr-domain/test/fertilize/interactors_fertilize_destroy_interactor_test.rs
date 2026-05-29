// Tests for `interactors/fertilize_destroy_interactor.rs` (Ruby parity under test/domain/fertilize/).

    use crate::fertilize::entities::{FertilizeEntity, FertilizeEntityAttrs};
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
            key.to_string()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct DestroyGateway {
        current: FertilizeEntity,
        undo: serde_json::Value,
    }

    impl FertilizeGateway for DestroyGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.current.clone())
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
            _: crate::shared::attr::AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<FertilizeEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
            Ok(SoftDeleteWithUndoOutcome::Success {
                undo: self.undo.clone(),
            })
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
        success: Option<FertilizeDestroyOutput>,
        failure: Option<DestroyFailure>,
    }

    impl FertilizeDestroyOutputPort for SpyOutput {
        fn on_success(&mut self, dto: FertilizeDestroyOutput) {
            self.success = Some(dto);
        }
        fn on_failure(&mut self, error: DestroyFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "calls on_success when delete is allowed"
    #[test]
    fn calls_on_success_when_delete_allowed() {
        let user_id = 10;
        let current = FertilizeEntity::new(FertilizeEntityAttrs {
            id: Some(7),
            user_id: Some(user_id),
            name: "F".into(),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid");
        let undo = serde_json::json!({"id": 1});
        let gateway = DestroyGateway {
            current,
            undo: undo.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(user_id, false));
        let mut interactor = FertilizeDestroyInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        interactor.call(7).expect("handled");
        assert_eq!(output.success.as_ref().map(|d| d.undo.clone()), Some(undo));
    }

    // Ruby: test "calls on_failure with policy exception when permission denied"
    #[test]
    fn calls_on_failure_when_permission_denied() {
        let user_id = 10;
        let current = FertilizeEntity::new(FertilizeEntityAttrs {
            id: Some(7),
            user_id: Some(99),
            name: "F".into(),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid");
        let gateway = DestroyGateway {
            current,
            undo: serde_json::json!({}),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(user_id, false));
        let mut interactor = FertilizeDestroyInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        interactor.call(7).expect("handled");
        assert!(matches!(
            output.failure,
            Some(DestroyFailure::Policy(PolicyPermissionDenied))
        ));
    }
