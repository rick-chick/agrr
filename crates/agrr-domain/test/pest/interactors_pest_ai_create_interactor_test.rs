// Tests for `interactors/pest_ai_create_interactor.rs` (Ruby parity under test/domain/pest/).

    use crate::pest::entities::PestEntity;
    use crate::pest::ports::{PestAiCreateInteractorPort, PestAiCreateResult, PestAiUpdateInteractorPort, PestAiUpdateResult};
    use crate::shared::attr::AttrMap;
    use crate::shared::user::User;

    struct StubLookup {
        user: User,
    }

    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.user
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, _: &str, _: &TranslateOptions) -> String {
            "name required".to_string()
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

    struct NoopPestGateway;
    impl PestGateway for NoopPestGateway {

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
        ) -> Result<crate::pest::entities::PestEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn create_for_user(
            &self,
            _: &User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<crate::pest::entities::PestEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<crate::pest::entities::PestEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<
            Vec<crate::pest::entities::PestEntity>,
            Box<dyn std::error::Error + Send + Sync>,
        > {
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
        ) -> Result<crate::pest::dtos::PestDeleteUsage, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<
            crate::pest::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }
        fn find_by_name(
            &self,
            _: i64,
            _: &str,
        ) -> Result<Option<crate::pest::entities::PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct NoopAiGateway;
    impl PestAiQueryGateway for NoopAiGateway {
        fn fetch_pest_json(
            &self,
            _: &str,
            _: &[serde_json::Value],
        ) -> Result<serde_json::Value, Box<dyn std::error::Error + Send + Sync>> {
            Ok(serde_json::json!({}))
        }
    }

    struct NoopCreate;
    impl PestAiCreateInteractorPort for NoopCreate {
        fn call(&self, _: AttrMap) -> PestAiCreateResult {
            PestAiCreateResult {
                success: false,
                data: None,
                error: Some("noop".into()),
            }
        }
    }

    struct NoopUpdate;
    impl PestAiUpdateInteractorPort for NoopUpdate {
        fn call(&self, _: i64, _: AttrMap) -> PestAiUpdateResult {
            PestAiUpdateResult {
                success: false,
                data: None,
                error: Some("noop".into()),
            }
        }
    }

    struct NoopAssociateRunner;
    impl AssociateAffectedCropsRunner for NoopAssociateRunner {
        fn call(
            &self,
            _: i64,
            _: &[serde_json::Value],
        ) -> Result<i64, Box<dyn std::error::Error + Send + Sync>> {
            Ok(0)
        }
    }

    struct SpyAiOutput {
        failure: Option<PestAiCreateFailure>,
    }

    impl PestAiCreateOutputPort for SpyAiOutput {
        fn on_success(&mut self, _: PestAiCreateOutput) {}
        fn on_failure(&mut self, error: PestAiCreateFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "calls on_failure when pest name is blank"
    #[test]
    fn calls_on_failure_when_pest_name_is_blank() {
        let mut output = SpyAiOutput { failure: None };
        let lookup = StubLookup {
            user: User::new(1, false),
        };
        let mut interactor = PestAiCreateInteractor::new(
            &mut output,
            1,
            &lookup,
            &NoopPestGateway,
            &NoopAiGateway,
            &NoopCreate,
            &NoopUpdate,
            &NoopAssociateRunner,
            &NoopLogger,
            &StubTranslator,
        );
        interactor.call(Some("  "), &[]).expect("handled");
        let failure = output.failure.expect("failure");
        assert_eq!(failure.message, "name required");
        assert_eq!(failure.http_status, HttpStatus::BadRequest);
    }
