// Tests for `interactors/fertilize_create_interactor.rs` (Ruby parity under test/domain/fertilize/).

    use crate::fertilize::entities::{FertilizeEntity, FertilizeEntityAttrs};
    use crate::fertilize::gateways::FertilizeGateway;
    use crate::fertilize::ports::{CreateFailure, FertilizeCreateOutputPort};
    use crate::shared::attr::AttrMap;
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

    // Ruby: test "rejects a reference fertilize requested by a non-admin user"
    #[test]
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
