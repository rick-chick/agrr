// Tests for `interactors/agricultural_task_update_interactor.rs` (Ruby parity under test/domain/agricultural_task/).

    use crate::agricultural_task::entities::{AgriculturalTaskEntity, AgriculturalTaskEntityAttrs};
    use crate::agricultural_task::entities::CropTaskTemplateLinkEntity;
    use crate::agricultural_task::gateways::CropRecord;
    use crate::shared::user::User;

    struct MockUserLookup {
        user: User,
    }

    impl UserLookupGateway for MockUserLookup {
        fn find(&self, _user_id: i64) -> User {
            self.user
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

    struct SpyOutput {
        success: Option<AgriculturalTaskEntity>,
        failure: Option<UpdateFailure>,
    }

    impl AgriculturalTaskUpdateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: AgriculturalTaskEntity) {
            self.success = Some(entity);
        }

        fn on_failure(&mut self, error: UpdateFailure) {
            self.failure = Some(error);
        }
    }

    fn sample_current(user_id: i64) -> AgriculturalTaskEntity {
        AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(5),
            user_id: Some(user_id),
            name: "old".into(),
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: vec![],
            skill_level: None,
            region: Some("jp".into()),
            task_type: None,
            is_reference: false,
            created_at: None,
            updated_at: None,
        })
        .expect("valid")
    }

    struct NullCropGateways;

    impl CropGateway for NullCropGateways {
        fn list_by_is_reference(
            &self,
            _: bool,
            _: Option<&str>,
        ) -> Result<Vec<CropRecord>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }

        fn list_by_user_id(
            &self,
            _: i64,
            _: Option<&str>,
        ) -> Result<Vec<CropRecord>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }


    fn find_by_id(
            &self,
            _: i64,
        ) -> Result<CropRecord, Box<dyn std::error::Error + Send + Sync>> {
            Err(Box::new(RecordNotFoundError))
        }
    }

    struct NullTemplateGateway;

    impl CropTaskTemplateGateway for NullTemplateGateway {
        fn list_by_agricultural_task_id(
            &self,
            _: i64,
        ) -> Result<Vec<CropTaskTemplateLinkEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(vec![])
        }

        fn find_by_agricultural_task_id_and_crop_id(
            &self,
            _: i64,
            _: i64,
        ) -> Result<Option<CropTaskTemplateLinkEntity>, Box<dyn std::error::Error + Send + Sync>>
        {
            Ok(None)
        }

        fn create(
            &self,
            _: i64,
            _: i64,
            _: AttrMap,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }

        fn delete(
            &self,
            _: i64,
            _: i64,
        ) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
            Ok(())
        }
    }

    // Ruby: test "calls on_success when gateway updates"
    #[test]
    fn calls_on_success_when_gateway_updates() {
        let user_id = 10;
        let current = sample_current(user_id);
        let updated = AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(5),
            user_id: Some(user_id),
            name: "剪定".into(),
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: vec![],
            skill_level: None,
            region: Some("jp".into()),
            task_type: None,
            is_reference: false,
            created_at: None,
            updated_at: None,
        })
        .expect("valid");

        struct UpdateGateway {
            current: AgriculturalTaskEntity,
            updated: AgriculturalTaskEntity,
        }

        impl AgriculturalTaskGateway for UpdateGateway {
            fn list_user_owned_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_reference_tasks(
                &self,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_user_and_reference_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_agricultural_task_show_detail(
                &self,
                _: i64,
            ) -> Result<
                crate::agricultural_task::dtos::AgriculturalTaskShowDetail,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }

            fn find_by_id(
                &self,
                _: i64,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                Ok(self.current.clone())
            }

            fn find_by_reference_and_name(
                &self,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                Ok(None)
            }

            fn find_by_user_id_and_name(
                &self,
                _: i64,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                Ok(None)
            }

            fn create(
                &self,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }

            fn update(
                &self,
                _: i64,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                Ok(self.updated.clone())
            }

            fn within_transaction<F, T>(&self, block: F) -> T
            where
                F: FnOnce() -> T,
            {
                block()
            }

            fn soft_delete_with_undo(
                &self,
                _: &User,
                _: i64,
                _: i64,
                _: &str,
            ) -> Result<
                crate::agricultural_task::gateways::SoftDeleteUndoResult,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
        }

        let gateway = UpdateGateway {
            current,
            updated: updated.clone(),
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(user_id, false),
        };
        let mut interactor = AgriculturalTaskUpdateInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &NullCropGateways,
            &NullTemplateGateway,
            &StubTranslator,
            &user_lookup,
        );
        let input = AgriculturalTaskUpdateInput {
            id: 5,
            name: Some("剪定".into()),
            ..Default::default()
        };
        assert!(interactor.call(input).expect("ok"));
        assert_eq!(output.success.as_ref().map(|e| e.name.as_str()), Some("剪定"));
    }

    // Ruby: test "calls on_failure with policy_exception when permission is denied"
    #[test]
    fn calls_on_failure_when_permission_denied() {
        let user_id = 10;
        let current = sample_current(99);

        struct DenyGateway {
            current: AgriculturalTaskEntity,
        }

        impl AgriculturalTaskGateway for DenyGateway {
            fn list_user_owned_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_reference_tasks(
                &self,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_user_and_reference_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_agricultural_task_show_detail(
                &self,
                _: i64,
            ) -> Result<
                crate::agricultural_task::dtos::AgriculturalTaskShowDetail,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }

            fn find_by_id(
                &self,
                _: i64,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                Ok(self.current.clone())
            }

            fn find_by_reference_and_name(
                &self,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_by_user_id_and_name(
                &self,
                _: i64,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn create(
                &self,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }

            fn update(
                &self,
                _: i64,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                panic!("update should not be called");
            }

            fn within_transaction<F, T>(&self, block: F) -> T
            where
                F: FnOnce() -> T,
            {
                block()
            }

            fn soft_delete_with_undo(
                &self,
                _: &User,
                _: i64,
                _: i64,
                _: &str,
            ) -> Result<
                crate::agricultural_task::gateways::SoftDeleteUndoResult,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
        }

        let gateway = DenyGateway { current };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(user_id, false),
        };
        let mut interactor = AgriculturalTaskUpdateInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &NullCropGateways,
            &NullTemplateGateway,
            &StubTranslator,
            &user_lookup,
        );
        let input = AgriculturalTaskUpdateInput {
            id: 5,
            name: Some("x".into()),
            ..Default::default()
        };
        assert!(!interactor.call(input).expect("ok"));
        assert!(matches!(
            output.failure,
            Some(UpdateFailure::Policy(PolicyPermissionDenied))
        ));
    }

    // Ruby: test "一般ユーザーが is_reference を変更しようとすると on_failure"
    #[test]
    fn regular_user_cannot_change_is_reference() {
        let user_id = 10;
        let current = sample_current(user_id);

        struct RefGateway {
            current: AgriculturalTaskEntity,
        }

        impl AgriculturalTaskGateway for RefGateway {
            fn list_user_owned_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_reference_tasks(
                &self,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_user_and_reference_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_agricultural_task_show_detail(
                &self,
                _: i64,
            ) -> Result<
                crate::agricultural_task::dtos::AgriculturalTaskShowDetail,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }

            fn find_by_id(
                &self,
                _: i64,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                Ok(self.current.clone())
            }

            fn find_by_reference_and_name(
                &self,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_by_user_id_and_name(
                &self,
                _: i64,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn create(
                &self,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }

            fn update(
                &self,
                _: i64,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                panic!("update should not be called");
            }

            fn within_transaction<F, T>(&self, block: F) -> T
            where
                F: FnOnce() -> T,
            {
                block()
            }

            fn soft_delete_with_undo(
                &self,
                _: &User,
                _: i64,
                _: i64,
                _: &str,
            ) -> Result<
                crate::agricultural_task::gateways::SoftDeleteUndoResult,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
        }

        let gateway = RefGateway { current };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(user_id, false),
        };
        let mut interactor = AgriculturalTaskUpdateInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &NullCropGateways,
            &NullTemplateGateway,
            &StubTranslator,
            &user_lookup,
        );
        let input = AgriculturalTaskUpdateInput {
            id: 5,
            is_reference: Some(true),
            ..Default::default()
        };
        assert!(!interactor.call(input).expect("ok"));
        match output.failure {
            Some(UpdateFailure::ReferenceFlag(f)) => {
                assert_eq!(f.message, "agricultural_tasks.flash.reference_flag_admin_only");
                assert_eq!(f.resource_id, 5);
            }
            other => panic!("expected ReferenceFlag, got {other:?}"),
        }
    }

    // Ruby: test "同名がスコープ内に存在すると on_failure（name taken）"
    #[test]
    fn duplicate_name_fails() {
        let user_id = 10;
        let current = sample_current(user_id);
        let duplicate = AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(99),
            user_id: Some(user_id),
            name: "重複名".into(),
            ..Default::default()
        })
        .expect("valid");

        struct DupGateway {
            current: AgriculturalTaskEntity,
            duplicate: AgriculturalTaskEntity,
        }

        impl AgriculturalTaskGateway for DupGateway {
            fn list_user_owned_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_reference_tasks(
                &self,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn list_user_and_reference_tasks(
                &self,
                _: i64,
                _: Option<&str>,
            ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_agricultural_task_show_detail(
                &self,
                _: i64,
            ) -> Result<
                crate::agricultural_task::dtos::AgriculturalTaskShowDetail,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }

            fn find_by_id(
                &self,
                _: i64,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                Ok(self.current.clone())
            }

            fn find_by_reference_and_name(
                &self,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                unimplemented!()
            }

            fn find_by_user_id_and_name(
                &self,
                _: i64,
                _: &str,
            ) -> Result<Option<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>>
            {
                Ok(Some(self.duplicate.clone()))
            }

            fn create(
                &self,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                unimplemented!()
            }

            fn update(
                &self,
                _: i64,
                _: AttrMap,
            ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
                panic!("update should not be called");
            }

            fn within_transaction<F, T>(&self, block: F) -> T
            where
                F: FnOnce() -> T,
            {
                block()
            }

            fn soft_delete_with_undo(
                &self,
                _: &User,
                _: i64,
                _: i64,
                _: &str,
            ) -> Result<
                crate::agricultural_task::gateways::SoftDeleteUndoResult,
                Box<dyn std::error::Error + Send + Sync>,
            > {
                unimplemented!()
            }
        }

        let gateway = DupGateway {
            current,
            duplicate,
        };
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(user_id, false),
        };
        let mut interactor = AgriculturalTaskUpdateInteractor::new(
            &mut output,
            user_id,
            &gateway,
            &NullCropGateways,
            &NullTemplateGateway,
            &StubTranslator,
            &user_lookup,
        );
        let input = AgriculturalTaskUpdateInput {
            id: 5,
            name: Some("重複名".into()),
            ..Default::default()
        };
        assert!(!interactor.call(input).expect("ok"));
        match output.failure {
            Some(UpdateFailure::Error(e)) => {
                assert_eq!(
                    e.message,
                    "activerecord.errors.models.agricultural_task.attributes.name.taken"
                );
            }
            other => panic!("expected Error, got {other:?}"),
        }
    }
