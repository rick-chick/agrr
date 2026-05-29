// Tests for `interactors/pesticide_destroy_interactor.rs` (Ruby parity under test/domain/pesticide/).

    use crate::pesticide::entities::{PesticideEntity, PesticideEntityAttrs};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator;
    impl TranslatorPort for StubTranslator {
        fn translate(&self, _: &str, _: &TranslateOptions) -> String {
            String::new()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct DestroyGateway {
        current: PesticideEntity,
    }

    impl PesticideGateway for DestroyGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.current.clone())
        }

        fn list_index_for_filter(
            &self,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn find_pesticide_show_detail(
            &self,
            _: i64,
        ) -> Result<
            crate::pesticide::gateways::PesticideShowDetailGatewayDto,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
        }

        fn create_for_user(
            &self,
            _: &User,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<SoftDeleteWithUndoOutcome, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!("should not be called when edit denied")
        }

        fn list_by_crop_id_for_filter(
            &self,
            _: i64,
            _: &crate::shared::value_objects::reference_index_list_filter::ReferenceIndexListFilter,
        ) -> Result<Vec<PesticideEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    struct SpyOutput {
        failure: Option<DestroyFailure>,
    }

    impl PesticideDestroyOutputPort for SpyOutput {
        fn on_success(&mut self, _: PesticideDestroyOutput) {}
        fn on_failure(&mut self, error: DestroyFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "calls on_failure with policy exception when permission denied"
    #[test]
    fn calls_on_failure_with_policy_exception_when_permission_denied() {
        let current = PesticideEntity::new(PesticideEntityAttrs {
            id: 7,
            user_id: Some(99),
            name: "P".into(),
            active_ingredient: None,
            description: None,
            crop_id: None,
            pest_id: None,
            region: None,
            is_reference: false,
            created_at: "2026-01-01T00:00:00Z".into(),
            updated_at: "2026-01-01T00:00:00Z".into(),
        })
        .expect("valid");
        let gateway = DestroyGateway { current };
        let mut output = SpyOutput { failure: None };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = PesticideDestroyInteractor::new(
            &mut output,
            10,
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
