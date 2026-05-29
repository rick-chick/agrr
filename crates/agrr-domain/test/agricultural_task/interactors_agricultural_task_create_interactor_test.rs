// Tests for `interactors/agricultural_task_create_interactor.rs` (Ruby parity under test/domain/agricultural_task/).

    use crate::agricultural_task::entities::AgriculturalTaskEntityAttrs;
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
        fn translate(&self, key: &str, _: &crate::shared::ports::TranslateOptions) -> String {
            key.to_string()
        }

        fn localize(
            &self,
            _: time::Date,
            _: Option<&str>,
            _: &crate::shared::ports::TranslateOptions,
        ) -> String {
            String::new()
        }
    }

    struct MockGateway {
        create_attrs: Option<crate::shared::attr::AttrMap>,
        existing_id: Option<i64>,
        entity: Option<AgriculturalTaskEntity>,
    }

    impl AgriculturalTaskGateway for MockGateway {
        fn list_user_owned_tasks(
            &self,
            _: i64,
            _: Option<&str>,
        ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }

        fn list_reference_tasks(
            &self,
            _: Option<&str>,
        ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
        }

        fn list_user_and_reference_tasks(
            &self,
            _: i64,
            _: Option<&str>,
        ) -> Result<Vec<AgriculturalTaskEntity>, Box<dyn std::error::Error + Send + Sync>> {
            Ok(vec![])
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
            unimplemented!()
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
            if let Some(id) = self.existing_id {
                Ok(Some(
                    AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
                        id: Some(id),
                        user_id: Some(7),
                        name: "テスト作業".into(),
                        description: None,
                        time_per_sqm: None,
                        weather_dependency: None,
                        required_tools: vec![],
                        skill_level: None,
                        region: None,
                        task_type: None,
                        is_reference: false,
                        created_at: None,
                        updated_at: None,
                    })
                    .expect("valid"),
                ))
            } else {
                Ok(None)
            }
        }

        fn create(
            &self,
            attrs: crate::shared::attr::AttrMap,
        ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
            assert!(self.create_attrs.is_none());
            let _ = attrs;
            Ok(self.entity.clone().expect("entity"))
        }

        fn update(
            &self,
            _: i64,
            _: crate::shared::attr::AttrMap,
        ) -> Result<AgriculturalTaskEntity, Box<dyn std::error::Error + Send + Sync>> {
            unimplemented!()
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

    struct SpyOutput {
        success: Option<AgriculturalTaskEntity>,
        failure: Option<Error>,
    }

    impl AgriculturalTaskCreateOutputPort for SpyOutput {
        fn on_success(&mut self, entity: AgriculturalTaskEntity) {
            self.success = Some(entity);
        }

        fn on_failure(&mut self, error: Error) {
            self.failure = Some(error);
        }
    }

    fn sample_entity() -> AgriculturalTaskEntity {
        AgriculturalTaskEntity::new(AgriculturalTaskEntityAttrs {
            id: Some(1),
            user_id: Some(7),
            name: "テスト作業".into(),
            description: None,
            time_per_sqm: None,
            weather_dependency: None,
            required_tools: vec![],
            skill_level: None,
            region: None,
            task_type: None,
            is_reference: false,
            created_at: None,
            updated_at: None,
        })
        .expect("valid")
    }

    // Ruby: test "一般ユーザーが参照作業を作成しようとすると on_failure（reference_only_admin）"
    #[test]
    fn regular_user_reference_create_fails() {
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let gateway = MockGateway {
            create_attrs: None,
            existing_id: None,
            entity: Some(sample_entity()),
        };
        let user_lookup = MockUserLookup {
            user: User::new(7, false),
        };
        let translator = StubTranslator;
        let mut interactor = AgriculturalTaskCreateInteractor::new(
            &mut output,
            7,
            &gateway,
            &translator,
            &user_lookup,
        );
        let input = AgriculturalTaskCreateInput {
            is_reference: Some(true),
            ..AgriculturalTaskCreateInput::new("テスト作業")
        };
        interactor.call(input).expect("handled");
        assert_eq!(
            output.failure.as_ref().map(|e| e.message.as_str()),
            Some("agricultural_tasks.flash.reference_only_admin")
        );
    }

    // Ruby: test "admin は参照作業を作成でき on_success"
    #[test]
    fn admin_reference_create_succeeds() {
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let gateway = MockGateway {
            create_attrs: None,
            existing_id: None,
            entity: Some(sample_entity()),
        };
        let user_lookup = MockUserLookup {
            user: User::new(7, true),
        };
        let translator = StubTranslator;
        let mut interactor = AgriculturalTaskCreateInteractor::new(
            &mut output,
            7,
            &gateway,
            &translator,
            &user_lookup,
        );
        let input = AgriculturalTaskCreateInput {
            is_reference: Some(true),
            ..AgriculturalTaskCreateInput::new("テスト作業")
        };
        interactor.call(input).expect("handled");
        assert!(output.success.is_some());
    }

    // Ruby: test "一般ユーザーの非参照作業作成は呼び出しユーザー所有で on_success"
    #[test]
    fn regular_user_owned_create_succeeds() {
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let gateway = MockGateway {
            create_attrs: None,
            existing_id: None,
            entity: Some(sample_entity()),
        };
        let user_lookup = MockUserLookup {
            user: User::new(7, false),
        };
        let translator = StubTranslator;
        let mut interactor = AgriculturalTaskCreateInteractor::new(
            &mut output,
            7,
            &gateway,
            &translator,
            &user_lookup,
        );
        let input = AgriculturalTaskCreateInput {
            is_reference: Some(false),
            ..AgriculturalTaskCreateInput::new("テスト作業")
        };
        interactor.call(input).expect("handled");
        assert!(output.success.is_some());
    }

    // Ruby: test "同名がスコープ内に存在すると on_failure（name taken）"
    #[test]
    fn duplicate_name_fails() {
        let mut output = SpyOutput {
            success: None,
            failure: None,
        };
        let gateway = MockGateway {
            create_attrs: None,
            existing_id: Some(99),
            entity: None,
        };
        let user_lookup = MockUserLookup {
            user: User::new(7, false),
        };
        let translator = StubTranslator;
        let mut interactor = AgriculturalTaskCreateInteractor::new(
            &mut output,
            7,
            &gateway,
            &translator,
            &user_lookup,
        );
        let input = AgriculturalTaskCreateInput {
            is_reference: Some(false),
            ..AgriculturalTaskCreateInput::new("テスト作業")
        };
        interactor.call(input).expect("handled");
        assert_eq!(
            output.failure.as_ref().map(|e| e.message.as_str()),
            Some("activerecord.errors.models.agricultural_task.attributes.name.taken")
        );
    }
