// Tests for `interactors/pest_detail_interactor.rs` (Ruby parity under test/domain/pest/).

    use crate::pest::dtos::PestShowDetail;
    use crate::pest::entities::{PestEntity, PestEntityAttrs};
    use crate::shared::user::User;

    struct StubLookup(User);
    impl UserLookupGateway for StubLookup {
        fn find(&self, _: i64) -> User {
            self.0
        }
    }

    struct StubTranslator {
        message: Option<&'static str>,
    }

    impl TranslatorPort for StubTranslator {
        fn translate(&self, key: &str, _: &TranslateOptions) -> String {
            if key == "pests.flash.no_permission" {
                self.message.unwrap_or(key).to_string()
            } else {
                key.to_string()
            }
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    fn pest(is_reference: bool, user_id: Option<i64>) -> PestEntity {
        PestEntity::new(PestEntityAttrs {
            id: Some(3),
            user_id,
            name: "p".into(),
            is_reference,
            ..Default::default()
        })
        .expect("valid")
    }

    struct DetailGateway {
        detail: PestShowDetail,
    }

    impl PestGateway for DetailGateway {

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
            unimplemented!()
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
        ) -> Result<PestShowDetail, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.detail.clone())
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
        ) -> Result<Option<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
    }

    fn show_detail(pest: PestEntity) -> PestShowDetail {
        PestShowDetail {
            pest,
            temperature_profile: None,
            thermal_requirement: None,
            control_methods: vec![],
            associated_crops: vec![],
        }
    }

    struct SpyOutput {
        success: Option<PestDetailOutput>,
        failure: Option<DetailFailure>,
    }

    impl PestDetailOutputPort for SpyOutput {
        fn on_success(&mut self, output: PestDetailOutput) {
            self.success = Some(output);
        }
        fn on_failure(&mut self, error: DetailFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "calls on_success with detail dto when view is allowed"
    #[test]
    fn calls_on_success_with_detail_when_view_allowed() {
        let detail = show_detail(pest(true, None));
        let gateway = DetailGateway { detail };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let translator = StubTranslator { message: None };
        let mut interactor = PestDetailInteractor::new(
            &mut output,
            10,
            &gateway,
            &translator,
            &lookup,
        );
        interactor.call(3).expect("handled");
        let success = output.success.expect("success");
        assert_eq!(success.pest.id, 3);
        assert!(success.pest.is_reference);
    }

    // Ruby: test "calls on_failure with no_permission when view is denied"
    #[test]
    fn calls_on_failure_with_no_permission_when_view_denied() {
        let detail = show_detail(pest(false, Some(99)));
        let gateway = DetailGateway { detail };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let translator = StubTranslator {
            message: Some("no permission"),
        };
        let mut interactor = PestDetailInteractor::new(
            &mut output,
            10,
            &gateway,
            &translator,
            &lookup,
        );
        interactor.call(3).expect("handled");
        match output.failure {
            Some(DetailFailure::Error(err)) => assert_eq!(err.message, "no permission"),
            other => panic!("expected Error failure, got {other:?}"),
        }
    }
