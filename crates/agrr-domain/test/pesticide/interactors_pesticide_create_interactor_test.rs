// Tests for `interactors/pesticide_create_interactor.rs` (Ruby parity under test/domain/pesticide/).

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

    struct PolicyDeniedGateway;
    impl PesticideGateway for PolicyDeniedGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
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
            Err(Box::new(PolicyPermissionDenied))
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
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
        success: Option<PesticideEntity>,
        failure: Option<CreateFailure>,
    }

    impl PesticideCreateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: PesticideEntity) {
            self.success = Some(entity);
        }
        fn on_failure(&mut self, error: CreateFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_entity() -> PesticideEntity {
        PesticideEntity::new(PesticideEntityAttrs {
            id: 1,
            user_id: Some(10),
            name: "X".into(),
            active_ingredient: None,
            description: None,
            crop_id: Some(1),
            pest_id: Some(2),
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
        let gateway = PolicyDeniedGateway;
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = PesticideCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = PesticideCreateInput {
            name: "X".into(),
            crop_id: Some(1),
            pest_id: Some(2),
            ..PesticideCreateInput::new("X")
        };
        interactor.call(input).expect("handled");
        assert!(matches!(
            output.failure,
            Some(CreateFailure::Policy(PolicyPermissionDenied))
        ));
    }

    // Ruby: test "calls on_failure with Error when non-admin requests reference pesticide"
    #[test]
    fn calls_on_failure_when_non_admin_requests_reference_pesticide() {
        struct NeverCalledGateway;
        impl PesticideGateway for NeverCalledGateway {
            fn find_by_id(
                &self,
                _: i64,
            ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
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
                Ok(sample_entity())
            }
            fn update_for_user(
                &self,
                _: &User,
                _: i64,
                _: AttrMap,
            ) -> Result<PesticideEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
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

        let gateway = NeverCalledGateway;
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = PesticideCreateInteractor::new(
            &mut output,
            10,
            &gateway,
            &StubTranslator,
            &lookup,
        );
        let input = PesticideCreateInput {
            name: "参照農薬".into(),
            active_ingredient: Some("X".into()),
            crop_id: Some(1),
            pest_id: Some(2),
            is_reference: Some(true),
            ..PesticideCreateInput::new("参照農薬")
        };
        interactor.call(input).expect("handled");
        assert!(output.success.is_none());
        match output.failure {
            Some(CreateFailure::Error(e)) => {
                assert_eq!(e.message, "t:pesticides.flash.reference_only_admin");
            }
            other => panic!("expected Error, got {other:?}"),
        }
    }
