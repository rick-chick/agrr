// Tests for `interactors/pesticide_update_interactor.rs` (Ruby parity under test/domain/pesticide/).

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
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            format!("t:{key}")
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct UpdateGateway {
        current: PesticideEntity,
    }

    impl PesticideGateway for UpdateGateway {
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
            _: AttrMap,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!("should not be called when edit denied")
        }

        fn soft_delete_with_undo(
            &self,
            _: &User,
            _: i64,
            _: i64,
            _: &dyn TranslatorPort,
        ) -> Result<
            crate::pesticide::gateways::SoftDeleteWithUndoOutcome,
            Box<dyn std::error::Error + Send + Sync>,
        > {
            unimplemented!()
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
        failure: Option<UpdateFailure>,
    }

    impl PesticideUpdateOutputPort for SpyOutput {
        fn on_success(&mut self, _: PesticideEntity) {}
        fn on_failure(&mut self, error: UpdateFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_entity(user_id: i64) -> PesticideEntity {
        PesticideEntity::new(PesticideEntityAttrs {
            id: 5,
            user_id: Some(user_id),
            name: "Y".into(),
            active_ingredient: None,
            description: None,
            crop_id: None,
            pest_id: None,
            region: None,
            is_reference: false,
            created_at: "2026-01-01T00:00:00Z".into(),
            updated_at: "2026-01-01T00:00:00Z".into(),
        })
        .expect("valid")
    }

    // Ruby: test "calls on_failure with policy exception when permission denied"
    #[test]
    fn calls_on_failure_with_policy_exception_when_permission_denied() {
        let gateway = UpdateGateway {
            current: sample_entity(99),
        };
        let mut output = SpyOutput { failure: None };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = PesticideUpdateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = PesticideUpdateInput {
            pesticide_id: 5,
            name: Some("Y".into()),
            ..PesticideUpdateInput::new(5)
        };
        interactor.call(input).expect("handled");
        assert!(matches!(
            output.failure,
            Some(UpdateFailure::Policy(PolicyPermissionDenied))
        ));
    }

    // Ruby: test "calls on_failure with Error when non-admin toggles is_reference"
    #[test]
    fn calls_on_failure_when_non_admin_toggles_is_reference() {
        let gateway = UpdateGateway {
            current: sample_entity(10),
        };
        let mut output = SpyOutput { failure: None };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = PesticideUpdateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = PesticideUpdateInput {
            pesticide_id: 5,
            is_reference: Some(true),
            ..PesticideUpdateInput::new(5)
        };
        interactor.call(input).expect("handled");
        match output.failure {
            Some(UpdateFailure::ReferenceFlag(f)) => {
                assert_eq!(f.resource_id, 5);
                assert_eq!(f.message, "t:pesticides.flash.reference_flag_admin_only");
            }
            other => panic!("expected ReferenceFlag, got {other:?}"),
        }
    }
