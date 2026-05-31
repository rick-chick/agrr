// Tests for `interactors/fertilize_ai_create_interactor.rs` (Ruby parity under test/domain/fertilize/).

    use crate::fertilize::entities::FertilizeEntity;
    use crate::fertilize::ports::{AiCreateResult, AiUpdateResult};
    use crate::shared::user::User;

    struct AnonymousLookup;
    impl UserLookupGateway for AnonymousLookup {
        fn find(&self, _: i64) -> User {
            User {
                id: 1,
                admin: false,
                anonymous: true,
            }
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, _: &str, _: &TranslateOptions) -> String {
            "login required".into()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct NoopLogger;
    impl LoggerPort for NoopLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
    }

    struct NoopGateways;
    impl FertilizeGateway for NoopGateways {
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
            unimplemented!()
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
            Ok(None)
        }
    }

    impl FertilizeAiQueryGateway for NoopGateways {
        fn fetch_for_create(
            &self,
            _: &str,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn fetch_for_update(
            &self,
            _: i64,
            _: &str,
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct NoopAiPorts;
    impl AiCreateInteractorPort for NoopAiPorts {
        fn call(&self, _: AttrMap) -> AiCreateResult {
            AiCreateResult {
                success: false,
                data: None,
                error: Some("noop".into()),
            }
        }
    }
    impl AiUpdateInteractorPort for NoopAiPorts {
        fn call(&self, _: i64, _: AttrMap) -> AiUpdateResult {
            AiUpdateResult {
                success: false,
                data: None,
                error: Some("noop".into()),
            }
        }
    }

    struct SpyOutput {
        failure: Option<FertilizeAiCreateFailure>,
    }

    impl FertilizeAiCreateOutputPort for SpyOutput {
        fn on_success(&mut self, _: FertilizeAiCreateOutput) {}
        fn on_failure(&mut self, dto: FertilizeAiCreateFailure) {
            self.failure = Some(dto);
        }
    }

    // Ruby: test "calls on_failure when user is anonymous"
    #[test]
    fn calls_on_failure_when_user_is_anonymous() {
        let mut output = SpyOutput { failure: None };
        let mut interactor = FertilizeAiCreateInteractor::new(
            &mut output,
            1,
            &AnonymousLookup,
            &NoopGateways,
            &NoopGateways,
            &NoopAiPorts,
            &NoopAiPorts,
            &NoopLogger,
            &StubTranslator,
        );
        interactor.call("尿素").expect("handled");
        let failure = output.failure.expect("failure");
        assert_eq!(failure.http_status, HttpStatus::Unauthorized);
    }
