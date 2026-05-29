// Tests for `interactors/pest_destroy_interactor.rs` (Ruby parity under test/domain/pest/).

    use crate::pest::dtos::PestDeleteUsage;
    use crate::pest::entities::{PestEntity, PestEntityAttrs};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator {
        key: &'static str,
        message: &'static str,
    }

    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            if key == self.key {
                self.message.to_string()
            } else {
                key.to_string()
            }
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    fn owned_pest(user_id: i64) -> PestEntity {
        PestEntity::new(PestEntityAttrs {
            id: Some(7),
            user_id: Some(user_id),
            name: "p".into(),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid")
    }

    struct DestroyGateway {
        current: PestEntity,
        usage: PestDeleteUsage,
        undo: serde_json::Value,
        block_soft_delete: bool,
    }

    impl PestGateway for DestroyGateway {

        fn list_pests_for_crop_filtered(
            &self,
            _: i64,
            _: &[i64],
            _: crate::pest::gateways::CropPestListOrder,
        ) -> Result<Vec<crate::pest::entities::PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.current.clone())
        }
        fn create_for_user(
            &self,
            _: &User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn find_pest_show_detail(
            &self,
            _: i64,
        ) -> Result<crate::pest::dtos::PestShowDetail, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn find_delete_usage(
            &self,
            _: i64,
        ) -> Result<PestDeleteUsage, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.usage)
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
            if self.block_soft_delete {
                unimplemented!()
            }
            Ok(SoftDeleteWithUndoOutcome::Success {
                undo: self.undo.clone(),
            })
        }
        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyOutput {
        success: Option<PestDestroyOutput>,
        failure: Option<DestroyFailure>,
    }

    impl PestDestroyOutputPort for SpyOutput {
        fn on_success(&mut self, output: PestDestroyOutput) {
            self.success = Some(output);
        }
        fn on_failure(&mut self, error: DestroyFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "calls on_success when delete is allowed"
    #[test]
    fn calls_on_success_when_delete_is_allowed() {
        let user_id = 10;
        let gateway = DestroyGateway {
            current: owned_pest(user_id),
            usage: PestDeleteUsage::new(0),
            undo: serde_json::json!({"id": 1}),
            block_soft_delete: false,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(user_id, false));
        let translator = StubTranslator {
            key: "",
            message: "",
        };
        let mut interactor =
            PestDestroyInteractor::new(&mut output, user_id, &gateway, &translator, &lookup);
        interactor.call(7).expect("handled");
        assert_eq!(
            output.success.as_ref().map(|d| d.undo.clone()),
            Some(serde_json::json!({"id": 1}))
        );
    }

    // Ruby: test "calls on_failure when pesticides block delete"
    #[test]
    fn calls_on_failure_when_pesticides_block_delete() {
        let user_id = 10;
        let gateway = DestroyGateway {
            current: owned_pest(user_id),
            usage: PestDeleteUsage::new(2),
            undo: serde_json::json!({}),
            block_soft_delete: true,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(user_id, false));
        let translator = StubTranslator {
            key: "pests.flash.cannot_delete_in_use",
            message: "blocked",
        };
        let mut interactor =
            PestDestroyInteractor::new(&mut output, user_id, &gateway, &translator, &lookup);
        interactor.call(7).expect("handled");
        match output.failure {
            Some(DestroyFailure::Error(err)) => assert_eq!(err.message, "blocked"),
            other => panic!("expected Error failure, got {other:?}"),
        }
    }

    // Ruby: test "calls on_failure with Error when permission denied"
    #[test]
    fn calls_on_failure_when_permission_denied() {
        let user_id = 10;
        let gateway = DestroyGateway {
            current: owned_pest(99),
            usage: PestDeleteUsage::new(0),
            undo: serde_json::json!({}),
            block_soft_delete: false,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(user_id, false));
        let translator = StubTranslator {
            key: "pests.flash.no_permission",
            message: "denied",
        };
        let mut interactor =
            PestDestroyInteractor::new(&mut output, user_id, &gateway, &translator, &lookup);
        interactor.call(7).expect("handled");
        match output.failure {
            Some(DestroyFailure::Error(err)) => assert_eq!(err.message, "denied"),
            other => panic!("expected Error failure, got {other:?}"),
        }
    }
