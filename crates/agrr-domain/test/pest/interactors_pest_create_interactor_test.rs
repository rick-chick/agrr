// Tests for `interactors/pest_create_interactor.rs` (Ruby parity under test/domain/pest/).

    use crate::pest::entities::{PestEntity, PestEntityAttrs};
    use crate::pest::gateways::PestGateway;
    use crate::pest::ports::{CreateFailure, PestCreateOutputPort};
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
            key.to_string()
        }
        fn localize(&self, _: time::Date, _: Option<&str>, _: &TranslateOptions) -> String {
            String::new()
        }
    }

    struct SpyGateway {
        entity: PestEntity,
    }

    impl PestGateway for SpyGateway {

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
            attrs: AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            Ok(self.entity.clone())
        }

        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
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

    struct InvalidCreateGateway;
    impl PestGateway for InvalidCreateGateway {
        fn list_pests_for_crop_filtered(
            &self,
            _: i64,
            _: &[i64],
            _: crate::pest::gateways::CropPestListOrder,
        ) -> Result<Vec<PestEntity>, Box<dyn std::error::Error + Send + Sync>> {
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
            _: AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            Err(Box::new(RecordInvalidError::new(
                Some("invalid".into()),
                None,
            )))
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
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

    struct NoopCropGateway;
    impl CropGateway for NoopCropGateway {
        fn find_by_id(
            &self,
            _: i64,
        ) -> Result<Option<crate::pest::gateways::CropRecord>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(None)
        }
        fn list_by_name(
            &self,
            _: &str,
        ) -> Result<Vec<crate::pest::gateways::CropRecord>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }
    }

    struct NoopCropPestGateway;
    impl CropPestGateway for NoopCropPestGateway {
        fn find_by_crop_id_and_pest_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<crate::pest::entities::CropPestLinkEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(None)
        }
        fn list_by_pest_id(
            &self,
            _: i64,
        ) -> Result<Vec<i64>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }
        fn create(
            &self,
            _: i64,
            _: i64,
        ) -> Result<crate::pest::entities::CropPestLinkEntity, Box<dyn std::error::Error + Send + Sync>>
        {
            unimplemented!()
        }
        fn delete(&self, _: i64, _: i64) -> Result<bool, Box<dyn std::error::Error + Send + Sync>> {
            Ok(false)
        }
    }

    fn sample_pest(id: i64) -> PestEntity {
        PestEntity::new(PestEntityAttrs {
            id: Some(id),
            user_id: Some(7),
            name: "テスト害虫".into(),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid")
    }

    struct SpyOutput {
        success: Option<PestEntity>,
        failure: Option<CreateFailure>,
    }

    impl PestCreateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: PestEntity) {
            self.success = Some(entity);
        }
        fn on_failure(&mut self, error: CreateFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "一般ユーザーが参照害虫を作成しようとすると on_failure（reference_only_admin）"
    #[test]
    fn non_admin_cannot_create_reference_pest() {
        let gateway = SpyGateway {
            entity: sample_pest(1),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(7, false));
        let mut interactor = PestCreateInteractor::new(
            &mut output,
            7,
            &gateway,
            &NoopCropGateway,
            &NoopCropPestGateway,
            &StubTranslator,
            &lookup,
        );
        let mut input = PestCreateInput::new("テスト害虫");
        input.is_reference = Some(true);
        interactor.call(input).expect("handled");
        match output.failure {
            Some(CreateFailure::Error(err)) => {
                assert_eq!(err.message, "pests.flash.reference_only_admin")
            }
            other => panic!("expected failure, got {other:?}"),
        }
    }

    // Ruby: test "admin は参照害虫を作成でき on_success"
    #[test]
    fn admin_can_create_reference_pest() {
        let entity = sample_pest(1);
        let gateway = SpyGateway {
            entity: entity.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(7, true));
        let mut interactor = PestCreateInteractor::new(
            &mut output,
            7,
            &gateway,
            &NoopCropGateway,
            &NoopCropPestGateway,
            &StubTranslator,
            &lookup,
        );
        let mut input = PestCreateInput::new("テスト害虫");
        input.is_reference = Some(true);
        interactor.call(input).expect("handled");
        assert_eq!(output.success, Some(entity));
    }

    // Ruby: test "create の RecordInvalid 時は Error を返す"
    #[test]
    fn returns_error_when_create_raises_record_invalid() {
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(7, false));
        let mut interactor = PestCreateInteractor::new(
            &mut output,
            7,
            &InvalidCreateGateway,
            &NoopCropGateway,
            &NoopCropPestGateway,
            &StubTranslator,
            &lookup,
        );
        interactor
            .call(PestCreateInput::new("テスト害虫"))
            .expect("handled");
        match output.failure {
            Some(CreateFailure::Error(err)) => assert!(err.message.contains("invalid")),
            other => panic!("expected failure, got {other:?}"),
        }
    }
