// Tests for `interactors/pest_update_interactor.rs` (Ruby parity under test/domain/pest/).

    use crate::pest::entities::{PestEntity, PestEntityAttrs};
    use crate::shared::user::User;

    fn empty_input(pest_id: i64) -> PestUpdateInput {
        PestUpdateInput {
            pest_id,
            name: None,
            name_scientific: None,
            family: None,
            order: None,
            description: None,
            occurrence_season: None,
            region: None,
            is_reference: None,
            pest_temperature_profile_attributes: None,
            pest_thermal_requirement_attributes: None,
            pest_control_methods_attributes: None,
            crop_ids: None,
        }
    }

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

    struct NoopLogger;
    impl LoggerPort for NoopLogger {
        fn info(&self, _: &str) {}
        fn warn(&self, _: &str) {}
        fn error(&self, _: &str) {}
        fn debug(&self, _: &str) {}
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

    fn owned_pest(user_id: i64) -> PestEntity {
        PestEntity::new(PestEntityAttrs {
            id: Some(1),
            user_id: Some(user_id),
            name: "x".into(),
            is_reference: false,
            ..Default::default()
        })
        .expect("valid")
    }

    struct UpdateGateway {
        current: PestEntity,
        fail_update: bool,
    }

    impl PestGateway for UpdateGateway {


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
            _: AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
        }
        fn update_for_user(
            &self,
            _: &User,
            _: i64,
            _: AttrMap,
        ) -> Result<PestEntity, Box<dyn std::error::Error + Send + Sync>> {
            if self.fail_update {
                Err(Box::new(RecordInvalidError::new(
                    Some("update failed".into()),
                    None,
                )))
            } else {
                Ok(self.current.clone())
            }
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

    struct SpyOutput {
        success: Option<PestEntity>,
        failure: Option<UpdateFailure>,
    }

    impl PestUpdateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: PestEntity) {
            self.success = Some(entity);
        }
        fn on_failure(&mut self, error: UpdateFailure) {
            self.failure = Some(error);
        }
    }

    // Ruby: test "on_failure returns Error when update raises RecordInvalid"
    #[test]
    fn on_failure_returns_error_when_update_raises_record_invalid() {
        let gateway = UpdateGateway {
            current: owned_pest(10),
            fail_update: true,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = PestUpdateInteractor::new(
            &mut output,
            10,
            &gateway,
            &NoopCropGateway,
            &NoopCropPestGateway,
            &NoopLogger,
            &StubTranslator,
            &lookup,
        );
        interactor.call(empty_input(1)).expect("handled");
        match output.failure {
            Some(UpdateFailure::Error(err)) => assert!(err.message.contains("update failed")),
            other => panic!("expected Error failure, got {other:?}"),
        }
    }

    // Ruby: test "calls on_failure with PolicyPermissionDenied when edit is denied"
    #[test]
    fn calls_on_failure_with_policy_when_edit_denied() {
        let gateway = UpdateGateway {
            current: owned_pest(99),
            fail_update: false,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = PestUpdateInteractor::new(
            &mut output,
            10,
            &gateway,
            &NoopCropGateway,
            &NoopCropPestGateway,
            &NoopLogger,
            &StubTranslator,
            &lookup,
        );
        interactor.call(empty_input(1)).expect("handled");
        assert!(matches!(
            output.failure,
            Some(UpdateFailure::Policy(_))
        ));
    }

    // Ruby: test "一般ユーザーが is_reference を変更しようとすると on_failure（reference_flag_admin_only）"
    #[test]
    fn calls_on_failure_when_non_admin_changes_reference_flag() {
        let gateway = UpdateGateway {
            current: owned_pest(10),
            fail_update: false,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let lookup = StubLookup(User::new(10, false));
        let mut interactor = PestUpdateInteractor::new(
            &mut output,
            10,
            &gateway,
            &NoopCropGateway,
            &NoopCropPestGateway,
            &NoopLogger,
            &StubTranslator,
            &lookup,
        );
        let mut input = empty_input(1);
        input.is_reference = Some(true);
        interactor.call(input).expect("handled");
        assert!(matches!(
            output.failure,
            Some(UpdateFailure::ReferenceFlagChange(_))
        ));
    }
